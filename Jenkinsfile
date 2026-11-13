pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Verify Repository') {
            steps {
                echo 'Verifying project files...'
                sh '''
                    pwd
                    ls -la
                    git log -1 --oneline
                '''
            }
        }

         stage('Docker Verification') {
             steps {
                 echo 'Checking Docker Engine and Swarm access...'
                    sh '''
                       docker --version
                       docker info --format 'Swarm Status: {{.Swarm.LocalNodeState}}'
                       docker node ls
                       '''
            }
        }
        stage('Build Backend Image') {
                steps {
                    sh '''
                    docker build \
                    -t multi-tier-backend:ci-${BUILD_NUMBER} \
                    ./backend
                    '''
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                    docker build \
                    --build-arg VITE_API_URL=/api \
                    -t multi-tier-frontend:ci-${BUILD_NUMBER} \
                    ./frontend
                '''
            }

       }

        stage('Build ECS Images') {
            steps {
                sh '''
                    set -eu

                    IMAGE_TAG=$(git rev-parse HEAD)

                    docker build \
                      -t multi-tier-backend:ecs-${IMAGE_TAG} \
                      ./backend

                    docker build \
                      -f frontend/Dockerfile.ecs \
                      --build-arg VITE_API_URL=/api \
                      -t multi-tier-frontend:ecs-${IMAGE_TAG} \
                      ./frontend
                '''
            }
        }

        stage('Push Images to Amazon ECR') {
            steps {
                withCredentials([
                    aws(
                        credentialsId: 'aws-ecr-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {

sh '''#!/usr/bin/bash
    set -euo pipefail
    set +x
    REGION=ap-south-1
    REGISTRY=809554586055.dkr.ecr.ap-south-1.amazonaws.com
    IMAGE_TAG=$(git rev-parse HEAD)

    export DOCKER_CONFIG="$(mktemp -d)"
    trap 'docker logout "$REGISTRY" >/dev/null 2>&1 || true; rm -rf "$DOCKER_CONFIG"' EXIT

    docker run --rm \
      -e AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY \
      -e AWS_DEFAULT_REGION="$REGION" \
      public.ecr.aws/aws-cli/aws-cli:latest \
      ecr get-login-password --region "$REGION" |
      docker login \
        --username AWS \
        --password-stdin "$REGISTRY"

    docker tag \
      "multi-tier-backend:ecs-${IMAGE_TAG}" \
      "$REGISTRY/multi-tier-poc/backend:$IMAGE_TAG"

    docker tag \
      "multi-tier-frontend:ecs-${IMAGE_TAG}" \
      "$REGISTRY/multi-tier-poc/frontend:$IMAGE_TAG"

    docker push "$REGISTRY/multi-tier-poc/backend:$IMAGE_TAG"
    docker push "$REGISTRY/multi-tier-poc/frontend:$IMAGE_TAG"
'''
            }
        }
     }
     stage('Deploy Frontend to AWS ECS') {
       when {
    expression {
        env.GIT_BRANCH == 'origin/main' ||
        env.GIT_BRANCH == 'main'
    }
}
       steps {

        withCredentials([
            aws(
                credentialsId: 'aws-ecr-credentials',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
            )
        ]) {
            sh '''#!/usr/bin/bash
                set -euo pipefail
                set +x

                export IMAGE_TAG="$(git rev-parse HEAD)"

                echo "Deploying frontend image: $IMAGE_TAG"

                bash scripts/deploy-ecs-frontend.sh
            '''
        }
    }
}

        stage('Deploy to Docker Swarm') {
            steps {
                echo 'Deploying frontend and backend to local Docker Swarm...'

                sh '''
                    set -eu

                    docker service update \
                    --detach=false \
                    --image multi-tier-backend:ci-${BUILD_NUMBER} \
                    poc_backend

                    docker service update \
                    --detach=false \
                    --image multi-tier-frontend:ci-${BUILD_NUMBER} \
                    poc_frontend
                '''
            }
        }
        stage('Verify Deployment') {
            steps {
                echo 'Verifying Docker Swarm deployment...'

                sh '''
                    set -eu

                    docker service ls \
                    --filter name=poc_backend \
                    --filter name=poc_frontend

                    echo "Checking application HTTP response..."

                    docker run --rm --network host \
                    curlimages/curl:latest \
                    --fail --silent --show-error \
                    --retry 10 \
                    --retry-delay 3 \
                    --retry-connrefused \
                    http://localhost:8081/ > /dev/null

                    echo "Application HTTP check passed."
                '''
            }
        }
    }

    post {
        success {
            echo 'CI pipeline completed successfully!'
        }

        failure {
            echo 'CI pipeline failed. Check console output.'
        }
    }
}
