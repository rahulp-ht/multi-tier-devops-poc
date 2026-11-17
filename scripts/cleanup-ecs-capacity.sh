
#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${ECS_CLUSTER:?ECS_CLUSTER is required}"
ASG="multi-tier-poc-ecs-asg"
BASELINE="ecs-baseline-ec2-${BUILD_NUMBER:?}.txt"
fail() {
    echo "SAFE CLEANUP STOPPED: $*" >&2
    exit 1
}

[ -f "$BASELINE" ] || fail "Baseline file missing"

mapfile -t ORIGINAL < <(sort -u "$BASELINE" | grep '^i-')
[ "${#ORIGINAL[@]}" -eq 2 ] || fail "Expected 2 original instances"

# Identify exactly one temporary instance in the ASG.
read -r MIN DESIRED COUNT <<< "$(./aws-cli.sh autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,length(Instances)]' \
    --output text)"

[ "$MIN" -eq 3 ] && [ "$DESIRED" -eq 3 ] && [ "$COUNT" -eq 3 ] ||
    fail "ASG capacity differs from expected 3 instances"

mapfile -t MEMBERS < <(
    ./aws-cli.sh autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG" \
      --query 'AutoScalingGroups[0].Instances[].InstanceId' \
      --output text | tr '\t' '\n' | sort -u
)

for ID in "${ORIGINAL[@]}"; do
    printf '%s\n' "${MEMBERS[@]}" | grep -Fxq "$ID" ||
        fail "Original instance $ID is missing from ASG"
done

TEMP=""
for ID in "${MEMBERS[@]}"; do
    if ! printf '%s\n' "${ORIGINAL[@]}" | grep -Fxq "$ID"; then
        [ -z "$TEMP" ] || fail "Multiple temporary instances detected"
        TEMP="$ID"
    fi
done

[ -n "$TEMP" ] || fail "Temporary instance not found"
echo "Temporary EC2: $TEMP"

PROTECTED="$(./aws-cli.sh autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG" \
    --query "AutoScalingGroups[0].Instances[?InstanceId=='$TEMP'].ProtectedFromScaleIn | [0]" \
    --output text)"

[ "$PROTECTED" = "False" ] ||
    fail "Temporary instance has scale-in protection or unknown protection status"

# Find the temporary ECS container instance.
ARNS="$(./aws-cli.sh ecs list-container-instances \
    --cluster "$CLUSTER" \
    --query 'containerInstanceArns' --output text)"

[ -n "$ARNS" ] && [ "$ARNS" != "None" ] ||
    fail "No active ECS container instances"

TEMP_ARN="$(./aws-cli.sh ecs describe-container-instances \
    --cluster "$CLUSTER" \
    --container-instances $ARNS \
    --query "containerInstances[?ec2InstanceId=='$TEMP'].containerInstanceArn | [0]" \
    --output text)"

[ -n "$TEMP_ARN" ] && [ "$TEMP_ARN" != "None" ] ||
    fail "Temporary ECS container instance not found"

# Drain, allowing ECS to replace tasks on original instances.
./aws-cli.sh ecs update-container-instances-state \
    --cluster "$CLUSTER" \
    --container-instances "$TEMP_ARN" \
    --status DRAINING >/dev/null

echo "Waiting for task migration and service health..."

READY=0

for ATTEMPT in $(seq 1 90); do
    read -r TASKS PENDING <<< "$(./aws-cli.sh ecs describe-container-instances \
        --cluster "$CLUSTER" \
        --container-instances "$TEMP_ARN" \
        --query 'containerInstances[0].[runningTasksCount,pendingTasksCount]' \
        --output text)"

    HEALTHY=1

    [ "$TASKS" -eq 0 ] && [ "$PENDING" -eq 0 ] || HEALTHY=0

    for SERVICE in backend frontend; do
        NAME="multi-tier-poc-$SERVICE"

        read -r STATUS DESIRED RUNNING WAITING DEPLOYMENTS ROLLOUT <<< "$(
            ./aws-cli.sh ecs describe-services \
              --cluster "$CLUSTER" --services "$NAME" \
              --query 'services[0].[status,desiredCount,runningCount,pendingCount,length(deployments),deployments[0].rolloutState]' \
              --output text
        )"

        if [ "$STATUS" != "ACTIVE" ] ||
           [ "$DESIRED" -ne 2 ] ||
           [ "$RUNNING" -ne 2 ] ||
           [ "$WAITING" -ne 0 ] ||
           [ "$DEPLOYMENTS" -ne 1 ] ||
           [ "$ROLLOUT" != "COMPLETED" ]; then
            HEALTHY=0
            continue
        fi

        TG="$(./aws-cli.sh ecs describe-services \
            --cluster "$CLUSTER" --services "$NAME" \
            --query 'services[0].loadBalancers[0].targetGroupArn' \
            --output text)"

        [ "$TG" != "None" ] || fail "Missing ALB target group for $NAME"

        TARGETS="$(./aws-cli.sh elbv2 describe-target-health \
            --target-group-arn "$TG" \
            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
            --output text)"

        [ "$TARGETS" -eq 2 ] || HEALTHY=0
    done

    if [ "$HEALTHY" -eq 1 ]; then
        READY=1
        break
    fi

    echo "Waiting for ECS migration: attempt $ATTEMPT/90"
    sleep 20
done

[ "$READY" -eq 1 ] ||
    fail "Services not healthy after 30 minutes; EC2 retained"

# Recheck ASG capacity before changing it.
read -r MIN DESIRED COUNT <<< "$(./aws-cli.sh autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,length(Instances)]' \
    --output text)"

[ "$MIN" -eq 3 ] && [ "$DESIRED" -eq 3 ] && [ "$COUNT" -eq 3 ] ||
    fail "ASG capacity changed during cleanup"

echo "All checks passed. Removing drained temporary EC2."

./aws-cli.sh autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG" \
    --min-size 2

./aws-cli.sh autoscaling terminate-instance-in-auto-scaling-group \
    --instance-id "$TEMP" \
    --should-decrement-desired-capacity

echo "Termination requested for $TEMP; desired capacity reduced to 2"
