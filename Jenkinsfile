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
        
        // AWS Configuration (UNCHANGED)
        AWS_DEFAULT_REGION = 'us-west-2'
        AWS_ACCOUNT_ID     = '975050024946'
        
        // Application Configuration (UNCHANGED)
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
                echo "🐍 Checking Python..."
                sh '''
                    python3 --version
                    pip3 --version
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                echo "📦 Installing Python dependencies..."
                sh '''
                    pip3 install --upgrade pip
                    pip3 install -r app/requirements.txt
                '''
            }
        }

        stage('Test Application') {
            steps {
                echo "✅ Running syntax check..."
                sh '''
                    python3 -m py_compile app/main.py
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
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                echo "📤 Pushing Docker image to ECR..."
                sh '''
                    docker push ${IMAGE_URI}
                '''
            }
        }

        stage('Configure kubectl') {
            steps {
                echo "⚙️ Configuring kubectl for EKS..."
                sh '''
                    aws eks update-kubeconfig \
                        --region ${AWS_DEFAULT_REGION} \
                        --name ${CLUSTER_NAME}

                    kubectl get nodes
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "🚀 Deploying to EKS..."
                sh '''
                    kubectl apply -f k8s/namespace.yaml

                    sed "s|<IMAGE_URI>|${IMAGE_URI}|g" k8s/deployment.yaml | \
                        kubectl apply -f -

                    kubectl apply -f k8s/service.yaml

                    kubectl -n ${K8S_NAMESPACE} rollout status deployment/${APP_NAME} --timeout=5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                echo "✔️ Verifying deployment..."
                sh '''
                    kubectl -n ${K8S_NAMESPACE} get pods
                    kubectl -n ${K8S_NAMESPACE} get svc
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully!"
        }

        failure {
            echo "❌ Pipeline failed!"
        }

        cleanup {
            deleteDir()
        }
    }
}
