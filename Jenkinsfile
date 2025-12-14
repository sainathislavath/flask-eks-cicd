pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    environment {
        // GitHub Configuration
        GITHUB_REPO      = 'https://github.com/sainathislavath/flask-eks-cicd.git'
        
        // AWS Configuration
        AWS_DEFAULT_REGION = 'us-west-2'
        AWS_ACCOUNT_ID     = '975050024946'
        
        // Application Configuration
        APP_NAME           = 'flask-eks-app'
        ECR_REPO_NAME      = 'flask-app'
        CLUSTER_NAME       = 'flask-eks-cluster-dev'
        K8S_NAMESPACE      = 'flask-eks'
        IMAGE_TAG          = "${BUILD_NUMBER}"
        ECR_REGISTRY       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        IMAGE_URI          = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out code from GitHub..."
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Setup Python Environment') {
            steps {
                echo "🐍 Setting up Python environment..."
                sh '''
                    python --version
                    python -m venv venv || true
                    . venv/bin/activate || true
                    pip --version
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                echo "📦 Installing Python dependencies..."
                sh '''
                    . venv/bin/activate || true
                    pip install --upgrade pip
                    pip install -r app/requirements.txt
                '''
            }
        }

        stage('Test Application') {
            steps {
                echo "✅ Running tests..."
                sh '''
                    . venv/bin/activate || true
                    python -m py_compile app/main.py
                    echo "Python syntax check passed!"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image..."
                sh '''
                    echo "Building image: ${IMAGE_URI}"
                    docker build -t ${ECR_REPO_NAME}:${IMAGE_TAG} .
                    docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${IMAGE_URI}
                    docker images | grep ${ECR_REPO_NAME}
                '''
            }
        }

        stage('ECR Login') {
            steps {
                echo "🔐 Authenticating with AWS ECR..."
                sh '''
                    aws --version
                    aws sts get-caller-identity
                    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    echo "✅ ECR login successful"
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                echo "📤 Pushing Docker image to ECR..."
                sh '''
                    echo "Pushing: ${IMAGE_URI}"
                    docker push ${IMAGE_URI}
                    echo "✅ Image pushed successfully"
                '''
            }
        }

        stage('Configure kubectl') {
            steps {
                echo "⚙️ Configuring kubectl for EKS cluster..."
                sh '''
                    aws eks update-kubeconfig \
                        --region ${AWS_DEFAULT_REGION} \
                        --name ${CLUSTER_NAME}
                    
                    echo "Cluster info:"
                    kubectl cluster-info
                    
                    echo "Available nodes:"
                    kubectl get nodes
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "🚀 Deploying application to EKS..."
                sh '''
                    echo "Creating/updating namespace: ${K8S_NAMESPACE}"
                    kubectl apply -f k8s/namespace.yaml
                    
                    echo "Creating/updating deployment..."
                    cat k8s/deployment.yaml | \
                        sed -e "s|<IMAGE_URI>|${IMAGE_URI}|g" | \
                        kubectl apply -f -
                    
                    echo "Creating/updating service..."
                    kubectl apply -f k8s/service.yaml
                    
                    echo "Waiting for deployment rollout..."
                    kubectl -n ${K8S_NAMESPACE} rollout status deployment/${APP_NAME} --timeout=5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                echo "✔️ Verifying deployment..."
                sh '''
                    echo "Deployment status:"
                    kubectl -n ${K8S_NAMESPACE} get deployment ${APP_NAME}
                    
                    echo "Pods status:"
                    kubectl -n ${K8S_NAMESPACE} get pods
                    
                    echo "Services:"
                    kubectl -n ${K8S_NAMESPACE} get svc
                    
                    echo "Service endpoint:"
                    kubectl -n ${K8S_NAMESPACE} get svc flask-eks-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
                    echo ""
                '''
            }
        }
    }

    post {
        always {
            echo "📊 Post-build status:"
            sh '''
                echo "All Kubernetes resources in ${K8S_NAMESPACE}:"
                kubectl get all -n ${K8S_NAMESPACE} || true
                
                echo "Recent pod logs:"
                kubectl -n ${K8S_NAMESPACE} logs -l app=${APP_NAME} --tail=20 || true
            '''
        }

        success {
            echo "✅ Pipeline completed successfully!"
            sh '''
                echo "Deployment Summary:"
                echo "==================="
                echo "Application: ${APP_NAME}"
                echo "Image: ${IMAGE_URI}"
                echo "Cluster: ${CLUSTER_NAME}"
                echo "Namespace: ${K8S_NAMESPACE}"
                echo "Region: ${AWS_DEFAULT_REGION}"
                echo ""
                echo "Service Endpoint:"
                kubectl -n ${K8S_NAMESPACE} get svc flask-eks-service -o wide
            '''
        }

        failure {
            echo "❌ Pipeline failed!"
            sh '''
                echo "Debug information:"
                echo "=================="
                echo "Cluster status:"
                aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} || true
                
                echo "Pod events:"
                kubectl -n ${K8S_NAMESPACE} describe pods || true
                
                echo "Recent errors:"
                kubectl -n ${K8S_NAMESPACE} logs -l app=${APP_NAME} --tail=50 || true
            '''
        }

        cleanup {
            deleteDir()
        }
    }
}
