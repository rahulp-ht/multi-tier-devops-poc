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

        stage('Build') {
            steps {
                echo 'Build stage placeholder'
            }
        }

        stage('Test') {
            steps {
                echo 'Test stage placeholder'
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