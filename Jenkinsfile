
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '809554586055'
        AWS_REGISTRY = '809554586055.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_PREFIX = 'multi-tier-poc'
        ECS_CLUSTER = 'multi-tier-poc-cluster'
        AWS_CLI_IMAGE = 'public.ecr.aws/aws-cli/aws-cli:latest'
        IMAGE_TAG = ''
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()
                }
                echo "Building commit: ${env.IMAGE_TAG}"
            }
        }

        stage('Verify Repository') {
            steps {
                sh '''
                    set -eu
                    test -f backend/Dockerfile
                    test -f frontend/Dockerfile
                    test -f scripts/deploy-ecs-frontend.sh
                    test -f scripts/deploy-ecs-backend.sh
                    test -f swarm-stack.yml
                    docker version
                    git --version
                '''
            }
        }

        stage('Validate Application') {
            steps {
                sh '''
                    set -eu
                    docker run --rm \
                      -v "$PWD/backend:/app" \
                      -w /app \
                      node:22-alpine \
                      node --check server.js

                    bash -n scripts/deploy-ecs-frontend.sh
                    bash -n scripts/deploy-ecs-backend.sh
                '''
            }
        }

        stage('Build ECS Images') {
            steps {
                sh '''
                    set -eu

                    docker build \
                      -t "$AWS_REGISTRY/$ECR_PREFIX/backend:$IMAGE_TAG" \
                      ./backend

                    docker build \
                      -f frontend/Dockerfile \
                      --build-arg VITE_API_URL=/api \
                      -t "$AWS_REGISTRY/$ECR_PREFIX/frontend:$IMAGE_TAG" \
                      ./frontend
                '''
            }
        }

        stage('Push Images to Amazon ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x

                        AWS_CONFIG_DIR="$(mktemp -d)"
                        DOCKER_CONFIG="$(mktemp -d)"
                        export DOCKER_CONFIG
                        trap 'rm -rf "$AWS_CONFIG_DIR" "$DOCKER_CONFIG"' EXIT

                        aws_cli() {
                            docker run --rm \
                              -e AWS_ACCESS_KEY_ID \
                              -e AWS_SECRET_ACCESS_KEY \
                              -e AWS_SESSION_TOKEN \
                              -e AWS_DEFAULT_REGION="$AWS_REGION" \
                              "$AWS_CLI_IMAGE" "$@"
                        }

                        aws_cli ecr get-login-password |
                          docker login \
                            --username AWS \
                            --password-stdin "$AWS_REGISTRY"

                        for SERVICE in backend frontend; do
                            REPO="$ECR_PREFIX/$SERVICE"
                            IMAGE="$AWS_REGISTRY/$REPO:$IMAGE_TAG"

                            echo "Checking ECR: $IMAGE"

                            if aws_cli ecr describe-images \
                                --repository-name "$REPO" \
                                --image-ids "imageTag=$IMAGE_TAG" \
                                >/dev/null 2>&1; then

                                echo "Image already exists; skipping push: $SERVICE"
                            else
                                echo "Pushing $SERVICE image..."
                                docker push "$IMAGE"
                            fi
                        done
                    '''
                }
            }
        }

        stage('Deploy Backend to AWS ECS') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x
                        bash scripts/deploy-ecs-backend.sh
                    '''
                }
            }
        }

        stage('Deploy Frontend to AWS ECS') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x
                        bash scripts/deploy-ecs-frontend.sh
                    '''
                }
            }
        }

        stage('Verify ECS Deployment') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x

                        for SERVICE in backend frontend; do
                            EXPECTED="$AWS_REGISTRY/$ECR_PREFIX/$SERVICE:$IMAGE_TAG"

                            TASK_ARN="$(docker run --rm \
                              -e AWS_ACCESS_KEY_ID \
                              -e AWS_SECRET_ACCESS_KEY \
                              -e AWS_SESSION_TOKEN \
                              -e AWS_DEFAULT_REGION="$AWS_REGION" \
                              "$AWS_CLI_IMAGE" \
                              ecs describe-services \
                              --cluster "$ECS_CLUSTER" \
                              --services "$ECR_PREFIX-$SERVICE" \
                              --query 'services[0].taskDefinition' \
                              --output text)"

                            ACTUAL="$(docker run --rm \
                              -e AWS_ACCESS_KEY_ID \
                              -e AWS_SECRET_ACCESS_KEY \
                              -e AWS_SESSION_TOKEN \
                              -e AWS_DEFAULT_REGION="$AWS_REGION" \
                              "$AWS_CLI_IMAGE" \
                              ecs describe-task-definition \
                              --task-definition "$TASK_ARN" \
                              --query 'taskDefinition.containerDefinitions[0].image' \
                              --output text)"

                            echo "$SERVICE deployed image: $ACTUAL"
                            test "$ACTUAL" = "$EXPECTED"
                        done
                    '''
                }
            }
        }

        stage('Deploy to Docker Swarm') {
            steps {
                sh '''
                    set -eu
                    docker info --format '{{.Swarm.LocalNodeState}}' |
                      grep -qx active

                    docker stack deploy \
                      -c swarm-stack.yml \
                      multi-tier-poc
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -eu
                    docker stack services multi-tier-poc
                    echo "ECS images verified and Swarm deployment submitted."
                '''
            }
        }
    }

    post {
        success {
            echo "CI/CD SUCCESS: ${env.IMAGE_TAG}"
        }
        failure {
            echo 'CI/CD FAILED: Check Jenkins console output.'
        }
        always {
            echo 'Pipeline finished.'
        }
    }
}
