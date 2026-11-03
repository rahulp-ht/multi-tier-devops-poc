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
