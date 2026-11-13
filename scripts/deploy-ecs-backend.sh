#!/usr/bin/env bash
set -euo pipefail
set +x

REGION="ap-south-1"
ACCOUNT_ID="809554586055"
CLUSTER="multi-tier-poc-cluster"
SERVICE="multi-tier-poc-backend"
CONTAINER="backend"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/multi-tier-poc/backend:${IMAGE_TAG:?IMAGE_TAG is required}"
AWS_CLI_IMAGE="public.ecr.aws/aws-cli/aws-cli:latest"

aws_cli() {
    docker run --rm \
        -e AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY \
        -e AWS_SESSION_TOKEN \
        -e AWS_DEFAULT_REGION="$REGION" \
        "$AWS_CLI_IMAGE" "$@"
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Retrieving current ECS task definition..."

CURRENT_TASK_ARN=$(aws_cli ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --query 'services[0].taskDefinition' \
    --output text)

aws_cli ecs describe-task-definition \
    --task-definition "$CURRENT_TASK_ARN" \
    --query 'taskDefinition' \
    --output json > "$WORK_DIR/current.json"

jq --arg IMAGE "$IMAGE" --arg CONTAINER "$CONTAINER" '
{
    family,
    taskRoleArn,
    executionRoleArn,
    networkMode,
    containerDefinitions,
    volumes,
    placementConstraints,
    requiresCompatibilities,
    cpu,
    memory,
    pidMode,
    ipcMode,
    proxyConfiguration,
    inferenceAccelerators,
    ephemeralStorage,
    runtimePlatform
}
| with_entries(select(.value != null))
| .containerDefinitions |= map(
    if .name == $CONTAINER then .image = $IMAGE else . end
)
' "$WORK_DIR/current.json" > "$WORK_DIR/new.json"

echo "Registering new task definition..."

# The AWS CLI container needs access to the generated JSON file.
NEW_TASK_ARN=$(docker run --rm -i \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_SESSION_TOKEN \
    -e AWS_DEFAULT_REGION="$REGION" \
    "$AWS_CLI_IMAGE" \
    ecs register-task-definition \
    --cli-input-json "$(cat "$WORK_DIR/new.json")" \
    --tags key=Project,value=multi-tier-poc \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)
echo "Updating ECS backend service..."

aws_cli ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --task-definition "$NEW_TASK_ARN" \
    --query 'service.{Name:serviceName,TaskDefinition:taskDefinition}' \
    --output table
echo "Waiting for ECS deployment to stabilize (up to 20 minutes)..."

STABLE=0

for ATTEMPT in $(seq 1 40); do
    STATUS=$(aws_cli ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --query 'services[0].deployments[0].rolloutState' \
        --output text)

    RUNNING=$(aws_cli ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --query 'services[0].runningCount' \
        --output text)

    ACTIVE_TASK=$(aws_cli ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --query 'services[0].taskDefinition' \
        --output text)

    echo "Attempt $ATTEMPT/40: rollout=$STATUS, running=$RUNNING"

    if [ "$STATUS" = "COMPLETED" ] &&
       [ "$RUNNING" -ge 1 ] &&
       [ "$ACTIVE_TASK" = "$NEW_TASK_ARN" ]; then
        STABLE=1
        break
    fi

    if [ "$STATUS" = "FAILED" ]; then
        echo "ERROR: ECS deployment failed."
        exit 1
    fi

    sleep 30
done

if [ "$STABLE" -ne 1 ]; then
    echo "ERROR: ECS backend did not stabilize within the timeout."
    exit 1
fi

echo "ECS backend deployment successful: $NEW_TASK_ARN"
