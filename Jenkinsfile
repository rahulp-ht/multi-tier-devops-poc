
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        SONAR_CONTAINER = 'poc-sonarqube'
        SONAR_NETWORK = 'poc-security-net'
        SONAR_URL = 'http://sonarqube:9000'
        SONAR_PROJECT_KEY = 'multi-tier-devops-poc'
        JENKINS_VOLUME = 'jenkins_poc_home'
        TRIVY_IMAGE = 'aquasec/trivy:latest'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Repository') {
            steps {
                sh '''
                    set -eu
                    pwd
                    ls -la
                    git log -1 --oneline
                    test -f sonar-project.properties
                '''
            }
        }

        stage('Docker Verification') {
            steps {
                sh '''
                    set -eu
                    docker --version
                    docker info --format 'Swarm Status: {{.Swarm.LocalNodeState}}'
                    docker node ls
                '''
            }
        }

        stage('Start SonarQube') {
            steps {
                sh '''
                    set -eu

                    docker start "${SONAR_CONTAINER}" || \
                      test "$(docker inspect -f '{{.State.Running}}' "${SONAR_CONTAINER}")" = true

                    echo "Waiting for SonarQube..."

                    ready=0

                    for i in $(seq 1 60); do
                        status=$(docker run --rm \
                          --network "${SONAR_NETWORK}" \
                          curlimages/curl:latest \
                          -fsS "${SONAR_URL}/api/system/status" \
                          2>/dev/null || true)

                        if echo "$status" | grep -q '"status":"UP"'; then
                            ready=1
                            break
                        fi

                        sleep 5
                    done

                    test "$ready" -eq 1
                    echo "SonarQube is ready."
                '''
            }
        }

        stage('SonarQube Code Scan') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'sonarqube-token',
                        variable: 'SONAR_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        mkdir -p security-reports

                        docker run --rm \
                          --network "${SONAR_NETWORK}" \
                          --user "$(id -u):$(id -g)" \
                          -e SONAR_HOST_URL="${SONAR_URL}" \
                          -e SONAR_TOKEN \
                          -e SONAR_USER_HOME=/tmp/.sonar \
                          -v "${JENKINS_VOLUME}:/jenkins" \
                          -w "/jenkins/workspace/${JOB_NAME}" \
                          sonarsource/sonar-scanner-cli:latest \
                          -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
                          -Dsonar.working.directory=.scannerwork
                    '''
                }
            }
        }

        stage('SonarQube Quality Gate Report') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'sonarqube-token',
                        variable: 'SONAR_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        mkdir -p security-reports
                        test -f .scannerwork/report-task.txt

                        ce_task_url=$(sed -n 's/^ceTaskUrl=//p' \
                          .scannerwork/report-task.txt)

                        test -n "$ce_task_url"

                        completed=0

                        for i in $(seq 1 60); do
                            curl -fsS \
                              -H "Authorization: Bearer ${SONAR_TOKEN}" \
                              "$ce_task_url" \
                              > security-reports/sonar-task.json

                            if grep -q '"status":"SUCCESS"' \
                              security-reports/sonar-task.json; then
                                completed=1
                                break
                            fi

                            if grep -Eq '"status":"FAILED"|"status":"CANCELED"' \
                              security-reports/sonar-task.json; then
                                echo "SonarQube analysis failed."
                                exit 1
                            fi

                            sleep 5
                        done

                        test "$completed" -eq 1

                        analysis_id=$(sed -n \
                          's/.*"analysisId":"\\([^"]*\\)".*/\\1/p' \
                          security-reports/sonar-task.json)

                        test -n "$analysis_id"

                        curl -fsS \
                          -H "Authorization: Bearer ${SONAR_TOKEN}" \
                          --get \
                          --data-urlencode "analysisId=$analysis_id" \
                          "${SONAR_URL}/api/qualitygates/project_status" \
                          > security-reports/sonar-quality-gate.json

                        echo "SonarQube Quality Gate:"
                        cat security-reports/sonar-quality-gate.json
                    '''
                }
            }
        }

        stage('Stop SonarQube') {
            steps {
                sh '''
                    docker stop "${SONAR_CONTAINER}"
                '''
            }
        }

        stage('Build Backend Image') {
            steps {
                sh '''
                    set -eu

                    docker build \
                      -t multi-tier-backend:ci-${BUILD_NUMBER} \
                      ./backend
                '''
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                    set -eu

                    docker build \
                      --build-arg VITE_API_URL=/api \
                      -t multi-tier-frontend:ci-${BUILD_NUMBER} \
                      ./frontend
                '''
            }
        }

        stage('Trivy Backend Scan') {
            steps {
                sh '''
                    set -eu

                    mkdir -p security-reports

                    docker run --rm \
                      --user "$(id -u):$(id -g)" \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v "${JENKINS_VOLUME}:/jenkins" \
                      -v trivy_cache:/tmp/trivy-cache \
                      -e TRIVY_CACHE_DIR=/tmp/trivy-cache \
                      "${TRIVY_IMAGE}" image \
                      --format json \
                      --output "/jenkins/workspace/${JOB_NAME}/security-reports/trivy-backend.json" \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      multi-tier-backend:ci-${BUILD_NUMBER}
                '''
            }
        }

        stage('Trivy Frontend Scan') {
            steps {
                sh '''
                    set -eu

                    docker run --rm \
                      --user "$(id -u):$(id -g)" \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v "${JENKINS_VOLUME}:/jenkins" \
                      -v trivy_cache:/tmp/trivy-cache \
                      -e TRIVY_CACHE_DIR=/tmp/trivy-cache \
                      "${TRIVY_IMAGE}" image \
                      --format json \
                      --output "/jenkins/workspace/${JOB_NAME}/security-reports/trivy-frontend.json" \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      multi-tier-frontend:ci-${BUILD_NUMBER}
                '''
            }
        }

        stage('Deploy to Docker Swarm') {
          when {
                expression { !params.SCAN_ONLY }
               }

            steps {
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
          when {
              expression { !params.SCAN_ONLY }
            }
            steps {
                sh '''
                    set -eu

                    docker service ls \
                      --filter name=poc_backend \
                      --filter name=poc_frontend

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
        always {
            archiveArtifacts(
                artifacts: 'security-reports/**/*',
                allowEmptyArchive: true
            )

            sh '''
                docker stop "${SONAR_CONTAINER}" 2>/dev/null || true
            '''
        }

        success {
            echo 'CI/CD pipeline completed successfully!'
        }

        failure {
            echo 'CI/CD pipeline failed. Check console output and security reports.'
        }
    }
}
