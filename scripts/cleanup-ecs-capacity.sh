#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${ECS_CLUSTER:?ECS_CLUSTER is required}"
ASG="multi-tier-poc-ecs-asg"
BASELINE="ecs-baseline-ec2-${BUILD_NUMBER:?}.txt"
AWS="./aws-cli.sh"

fail() { echo "SAFE CLEANUP STOPPED: $*" >&2; exit 1; }
contains() {
    local wanted="$1" item
    shift
    for item in "$@"; do
        [[ "$item" == "$wanted" ]] && return 0
    done
    return 1
}

[[ -x "$AWS" ]] || fail "AWS CLI wrapper missing or not executable"
[[ -f "$BASELINE" ]] || fail "Baseline file missing"
mapfile -t ORIGINAL < <(grep -E '^i-[0-9a-f]+$' "$BASELINE" | sort -u)
[[ "${#ORIGINAL[@]}" -eq 2 ]] || fail "Expected exactly 2 baseline EC2 instances"

load_asg() {
    read -r MIN DESIRED COUNT <<< "$("$AWS" autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,length(Instances)]' \
        --output text)"
    [[ "$MIN" =~ ^[0-9]+$ && "$DESIRED" =~ ^[0-9]+$ && "$COUNT" =~ ^[0-9]+$ ]] || fail "Invalid ASG response"
    (( MIN >= 2 && MIN <= 3 && DESIRED >= 2 && DESIRED <= 4 && COUNT == DESIRED )) ||
        fail "Unexpected ASG capacity: min=$MIN desired=$DESIRED instances=$COUNT"

    local raw
    raw="$("$AWS" autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text)"
    mapfile -t MEMBERS < <(printf '%s\n' "$raw" | tr '\t' '\n' | grep '^i-' | sort -u)
    [[ "${#MEMBERS[@]}" -eq "$COUNT" ]] || fail "ASG membership changed while checking"

    local id protection
    for id in "${ORIGINAL[@]}"; do
        contains "$id" "${MEMBERS[@]}" || fail "Original EC2 $id missing from ASG"
        protection="$("$AWS" autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$ASG" \
            --query "AutoScalingGroups[0].Instances[?InstanceId=='$id'].ProtectedFromScaleIn | [0]" \
            --output text)"
        [[ "$protection" == "True" ]] || fail "Original EC2 $id is not scale-in protected"
    done
    # Preserve the two baseline EC2 instances, one in each AZ.
    local first_az second_az
    first_az="$("$AWS" autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query "AutoScalingGroups[0].Instances[?InstanceId=='${ORIGINAL[0]}'].AvailabilityZone | [0]" \
        --output text)"
    second_az="$("$AWS" autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query "AutoScalingGroups[0].Instances[?InstanceId=='${ORIGINAL[1]}'].AvailabilityZone | [0]" \
        --output text)"
    [[ "$first_az $second_az" == 'ap-south-1a ap-south-1b' ||
       "$first_az $second_az" == 'ap-south-1b ap-south-1a' ]] ||
        fail "Baseline instances are not spread across both AZs"
}

services_healthy() {
    local name status desired running pending deployments rollout tg healthy
    for name in multi-tier-poc-backend multi-tier-poc-frontend; do
        read -r status desired running pending deployments rollout <<< "$("$AWS" ecs describe-services \
            --cluster "$CLUSTER" --services "$name" \
            --query 'services[0].[status,desiredCount,runningCount,pendingCount,length(deployments),deployments[0].rolloutState]' \
            --output text)"
        [[ "$status" == ACTIVE && "$desired" == 2 && "$running" == 2 && "$pending" == 0 && "$deployments" == 1 && "$rollout" == COMPLETED ]] || return 1
        tg="$("$AWS" ecs describe-services --cluster "$CLUSTER" --services "$name" \
            --query 'services[0].loadBalancers[0].targetGroupArn' --output text)"
        [[ -n "$tg" && "$tg" != None ]] || return 1
        healthy="$("$AWS" elbv2 describe-target-health --target-group-arn "$tg" \
            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)"
        [[ "$healthy" =~ ^[0-9]+$ ]] && (( healthy >= 2 )) || return 1
    done
}

find_ecs_arn() {
    local id="$1" active draining arns
    active="$("$AWS" ecs list-container-instances --cluster "$CLUSTER" --status ACTIVE \
        --query 'containerInstanceArns[]' --output text)"
    draining="$("$AWS" ecs list-container-instances --cluster "$CLUSTER" --status DRAINING \
        --query 'containerInstanceArns[]' --output text)"
    arns="$(printf '%s\n' "$active" "$draining" | tr '\t' '\n' | grep '^arn:' | sort -u | tr '\n' ' ')"
    [[ -n "$arns" ]] || fail "No ECS container instances found"
    # Intentional splitting: AWS CLI expects one argument per container instance ARN.
    "$AWS" ecs describe-container-instances --cluster "$CLUSTER" --container-instances $arns \
        --query "containerInstances[?ec2InstanceId=='$id'].containerInstanceArn | [0]" --output text
}

load_asg
while (( DESIRED > 2 )); do
    TEMP=""
    for id in "${MEMBERS[@]}"; do
        if ! contains "$id" "${ORIGINAL[@]}"; then TEMP="$id"; break; fi
    done
    [[ -n "$TEMP" ]] || fail "No temporary EC2 found"

    protection="$("$AWS" autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query "AutoScalingGroups[0].Instances[?InstanceId=='$TEMP'].ProtectedFromScaleIn | [0]" \
        --output text)"
    [[ "$protection" == False ]] || fail "Temporary EC2 $TEMP is scale-in protected"

    TEMP_ARN="$(find_ecs_arn "$TEMP")"
    [[ -n "$TEMP_ARN" && "$TEMP_ARN" != None ]] || fail "ECS registration missing for $TEMP"
    services_healthy || fail "Services are not healthy before draining $TEMP"

    echo "Draining temporary EC2: $TEMP"
    "$AWS" ecs update-container-instances-state --cluster "$CLUSTER" \
        --container-instances "$TEMP_ARN" --status DRAINING >/dev/null

    ready=0
    for attempt in $(seq 1 90); do
        read -r tasks pending <<< "$("$AWS" ecs describe-container-instances \
            --cluster "$CLUSTER" --container-instances "$TEMP_ARN" \
            --query 'containerInstances[0].[runningTasksCount,pendingTasksCount]' --output text)"
        if [[ "$tasks" == 0 && "$pending" == 0 ]] && services_healthy; then
            ready=1
            break
        fi
        echo "Waiting for task migration and health ($attempt/90)"
        sleep 20
    done
    [[ "$ready" == 1 ]] || fail "Migration timed out; $TEMP retained"

    previous_desired="$DESIRED"
    previous_members="$(printf '%s\n' "${MEMBERS[@]}")"
    load_asg
    [[ "$DESIRED" -eq "$previous_desired" && "$(printf '%s\n' "${MEMBERS[@]}")" == "$previous_members" ]] ||
        fail "ASG changed during drain; $TEMP retained"
    read -r tasks pending <<< "$("$AWS" ecs describe-container-instances \
        --cluster "$CLUSTER" --container-instances "$TEMP_ARN" \
        --query 'containerInstances[0].[runningTasksCount,pendingTasksCount]' --output text)"
    [[ "$tasks" == 0 && "$pending" == 0 ]] && services_healthy ||
        fail "Final ECS health check failed; $TEMP retained"

    if (( DESIRED == 3 )); then
        "$AWS" autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG" --min-size 2
    fi
    "$AWS" autoscaling terminate-instance-in-auto-scaling-group \
        --instance-id "$TEMP" --should-decrement-desired-capacity
    echo "Termination requested for $TEMP"

    expected=$((previous_desired - 1))
    removed=0
    for attempt in $(seq 1 60); do
        current_desired="$("$AWS" autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$ASG" \
            --query 'AutoScalingGroups[0].DesiredCapacity' --output text)"
        current_members="$("$AWS" autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$ASG" \
            --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text)"
        if [[ "$current_desired" == "$expected" ]] &&
           ! printf '%s\n' "$current_members" | tr '\t' '\n' | grep -Fxq "$TEMP"; then
            removed=1
            break
        fi
        sleep 10
    done
    [[ "$removed" == 1 ]] || fail "ASG did not settle after terminating $TEMP"
    load_asg
done

services_healthy || fail "Final services health check failed"
echo "Cleanup complete: 2 original EC2 instances retained, desired capacity 2"
