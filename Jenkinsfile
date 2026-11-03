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
