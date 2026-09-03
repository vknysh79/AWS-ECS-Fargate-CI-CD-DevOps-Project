pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'qa', 'stage', 'production'],
            description: 'Target deployment environment'
        )
        choice(
            name: 'DEPLOY_SLOT',
            choices: ['blue', 'green', 'none'],
            description: 'Target deployment slot (PRODUCTION ONLY - select blue or green for production; select none for dev/qa/stage)'
        )
        booleanParam(
            name: 'FORCE_NEW_DEPLOYMENT',
            defaultValue: true,
            description: 'Force a new ECS Fargate deployment'
        )
        booleanParam(
            name: 'ENABLE_SECURITY_SCAN',
            defaultValue: true,
            description: 'Enable Snyk & Trivy vulnerability scanners (Blocks deployment if HIGH/CRITICAL vulnerabilities found)'
        )
    }

    environment {
        AWS_REGION     = "us-east-1"
        ECR_REGISTRY   = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
        APP_NAME       = "devops-app"
        IMAGE_NAME     = "${params.ENVIRONMENT}-${APP_NAME}"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        ECS_CLUSTER    = "${params.ENVIRONMENT}-cluster"
        ECS_SERVICE    = "${params.ENVIRONMENT}-service"
        PREV_TASK_DEF  = ""
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
                script {
                    if (params.ENVIRONMENT == 'production') {
                        echo "Deploying to PRODUCTION using Blue/Green strategy (Slot: ${params.DEPLOY_SLOT})"
                    } else {
                        echo "Deploying to ${params.ENVIRONMENT.toUpperCase()} using Standard Rolling Deployment"
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    dir('app') {
                        appImage = docker.build("${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
                    }
                }
            }
        }

        stage('Security Scanning (Snyk & Trivy)') {
            when {
                expression { params.ENABLE_SECURITY_SCAN == true }
            }
            steps {
                script {
                    echo "🔒 STAGE 1/3: Executing Snyk Dependency Vulnerability Scan..."
                    try {
                        dir('app') {
                            sh 'snyk test --severity-threshold=high'
                        }
                        echo "✅ Snyk Dependency Scan PASSED."
                    } catch (Exception snykDepEx) {
                        error "DEPLOYMENT BLOCKED: Snyk detected HIGH/CRITICAL vulnerabilities in application dependencies!"
                    }

                    echo "STAGE 2/3: Executing Snyk Container Image Security Scan..."
                    try {
                        sh "snyk container test ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} --severity-threshold=high"
                        echo "Snyk Container Image Scan PASSED."
                    } catch (Exception snykImgEx) {
                        error "DEPLOYMENT BLOCKED: Snyk detected HIGH/CRITICAL vulnerabilities in container image!"
                    }

                    echo "STAGE 3/3: Executing Aqua Security Trivy Container Scan..."
                    try {
                        sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                        echo "✅Trivy Container Scan PASSED."
                    } catch (Exception trivyEx) {
                        error "DEPLOYMENT BLOCKED: Trivy detected HIGH/CRITICAL vulnerabilities in container image!"
                    }

                    echo "✅ALL SECURITY SCANS PASSED SUCCESSFULLY! Proceeding to ECR push and deployment."
                }
            }
        }

        stage('Authenticate & Push to ECR') {
            steps {
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}'
                script {
                    // Always push build number tag and latest tag
                    appImage.push()
                    sh "docker tag ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}/${IMAGE_NAME}:latest"
                    docker.image("${ECR_REGISTRY}/${IMAGE_NAME}:latest").push()

                    // Blue/Green slot tag pushing EXCLUSIVELY for PRODUCTION
                    if (params.ENVIRONMENT == 'production') {
                        if (params.DEPLOY_SLOT == 'blue' || params.DEPLOY_SLOT == 'green') {
                            sh "docker tag ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}/${IMAGE_NAME}:${params.DEPLOY_SLOT}"
                            docker.image("${ECR_REGISTRY}/${IMAGE_NAME}:${params.DEPLOY_SLOT}").push()
                            echo "Successfully pushed ${params.DEPLOY_SLOT} slot image to ECR for production."
                        } else {
                            error "DEPLOY_SLOT must be set to 'blue' or 'green' when deploying to production."
                        }
                    }
                }
            }
        }

        stage('Deploy to ECS Fargate & Health Probe Rollback') {
            steps {
                script {
                    echo "Capturing active Task Definition revision prior to deployment (for rollback)..."
                    PREV_TASK_DEF = sh(
                        script: "aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --region ${AWS_REGION} --query 'services[0].taskDefinition' --output text",
                        returnStdout: true
                    ).trim()
                    echo "Active Task Definition before update: ${PREV_TASK_DEF}"

                    try {
                        echo "Updating ECS Service ${ECS_SERVICE} on Cluster ${ECS_CLUSTER} for ${params.ENVIRONMENT}..."
                        def forceFlag = params.FORCE_NEW_DEPLOYMENT ? "--force-new-deployment" : ""
                        sh "aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} ${forceFlag} --region ${AWS_REGION}"

                        echo "Monitoring deployment: Waiting for container startup, liveness, and health probes to stabilize..."
                        sh "aws ecs wait services-stable --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --region ${AWS_REGION}"
                        echo "✅ Deployment completed successfully! Container startup & health probes passed. Service ${ECS_SERVICE} is stable."
                    } catch (Exception e) {
                        echo "❌DEPLOYMENT FAILED DURING CONTAINER STARTUP OR HEALTH PROBES: ${e.getMessage()}"

                        // Extract diagnostic details from recent stopped tasks (startup/liveness probe failures)
                        try {
                            echo "🔍 Diagnosing container failure details from AWS ECS..."
                            def stoppedTaskArn = sh(
                                script: "aws ecs list-tasks --cluster ${ECS_CLUSTER} --desired-status STOPPED --region ${AWS_REGION} --query 'taskArns[0]' --output text",
                                returnStdout: true
                            ).trim()
                            if (stoppedTaskArn && stoppedTaskArn != "None" && stoppedTaskArn != "null") {
                                def stoppedReason = sh(
                                    script: "aws ecs describe-tasks --cluster ${ECS_CLUSTER} --tasks ${stoppedTaskArn} --region ${AWS_REGION} --query 'tasks[0].stoppedReason' --output text",
                                    returnStdout: true
                                ).trim()
                                def containerExitCode = sh(
                                    script: "aws ecs describe-tasks --cluster ${ECS_CLUSTER} --tasks ${stoppedTaskArn} --region ${AWS_REGION} --query 'tasks[0].containers[0].exitCode' --output text",
                                    returnStdout: true
                                ).trim()
                                def containerReason = sh(
                                    script: "aws ecs describe-tasks --cluster ${ECS_CLUSTER} --tasks ${stoppedTaskArn} --region ${AWS_REGION} --query 'tasks[0].containers[0].reason' --output text",
                                    returnStdout: true
                                ).trim()
                                echo "📌 CONTAINER FAILURE DIAGNOSTICS:"
                                echo "   Task ARN: ${stoppedTaskArn}"
                                echo "   Task Stopped Reason: ${stoppedReason}"
                                echo "   Container Exit Code: ${containerExitCode}"
                                echo "   Container Failure Reason: ${containerReason}"
                            }
                        } catch (Exception diagEx) {
                            echo "Could not retrieve detailed task stop reasons: ${diagEx.getMessage()}"
                        }

                        // Initiate automated rollback
                        if (PREV_TASK_DEF && PREV_TASK_DEF != "None" && PREV_TASK_DEF != "null") {
                            echo "⚠️ INITIATING AUTOMATIC ROLLBACK to previous Task Definition revision: ${PREV_TASK_DEF} (avoiding :latest)..."
                            sh "aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${PREV_TASK_DEF} --force-new-deployment --region ${AWS_REGION}"
                            echo "Waiting for service to stabilize on rolled-back release version..."
                            sh "aws ecs wait services-stable --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --region ${AWS_REGION}"
                            echo "✅ AUTOMATIC ROLLBACK SUCCESSFUL! Service restored to previous release revision ${PREV_TASK_DEF}."
                        } else {
                            echo "⚠️ No previous Task Definition found to perform automated rollback."
                        }
                        error "Deployment failed due to startup or health probe failure. Automated rollback to previous release revision (${PREV_TASK_DEF}) was executed."
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.ENVIRONMENT == 'production') {
                    echo "Pipeline completed successfully! Application deployed to PRODUCTION ECS Fargate cluster (${params.DEPLOY_SLOT} slot)."
                } else {
                    echo "Pipeline completed successfully! Application deployed to ${params.ENVIRONMENT.toUpperCase()} ECS Fargate cluster via Rolling Deployment."
                }
            }
        }
        failure {
            echo "Pipeline execution failed on environment ${params.ENVIRONMENT}."
        }
    }
}
