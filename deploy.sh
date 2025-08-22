#!/bin/bash

set -e

# Configuration
PROJECT_NAME="bf-traveler"
ENVIRONMENT="dev"
AWS_REGION="eu-central-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    echo_info "Checking dependencies..."
    
    if ! command -v aws &> /dev/null; then
        echo_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        echo_error "Terraform is not installed"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v uv &> /dev/null; then
        echo_error "uv is not installed. Please install it (e.g., curl -LsSf https://astral.sh/uv/install.sh | sh)"
        exit 1
    fi
    
    echo_info "All dependencies are installed"
}

# Initialize Terraform
init_terraform() {
    echo_info "Initializing Terraform..."
    cd terraform
    
    if [ ! -f "terraform.tfvars" ]; then
        echo_warn "terraform.tfvars not found in terraform/ directory"
        echo_info "Copying terraform.tfvars.example to terraform.tfvars..."
        cp terraform.tfvars.example terraform.tfvars
        echo_error "Please update terraform/terraform.tfvars with your values and run the script again"
        echo_info "Make sure to set a secure value for 'nextauth_secret'"
        cd ..
        exit 1
    fi
    
    # Check if terraform.tfvars still has placeholder values
    if grep -q "CHANGE-ME-TO-A-SECURE-RANDOM-STRING" terraform.tfvars; then
        echo_warn "terraform.tfvars contains placeholder values"
        echo_error "Please update terraform/terraform.tfvars with your actual values"
        echo_info "Generate a secure nextauth_secret with: openssl rand -base64 32"
        echo_info "Then update the 'nextauth_secret' value in terraform/terraform.tfvars"
        cd ..
        exit 1
    fi
    
    echo_info "terraform.tfvars found and appears to be configured"
    terraform init
    cd ..
}

# Deploy infrastructure
deploy_infrastructure() {
    echo_info "Deploying infrastructure..."
    cd terraform
    terraform plan
    terraform apply -auto-approve
    
    # Get ECR repository URL
    ECR_REPO=$(terraform output -raw ecr_repository_url)
    echo_info "ECR Repository: $ECR_REPO"
    cd ..
}

# Build and push Docker image
build_and_push() {
    echo_info "Building and pushing Docker image..."
    
    # Get ECR repository URL from Terraform output
    cd terraform
    ECR_REPO=$(terraform output -raw ecr_repository_url)
    cd ..
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
    
    # Build image
    cd front/bf_traveler
    docker build -t $PROJECT_NAME-$ENVIRONMENT .
    
    # Tag and push image
    docker tag $PROJECT_NAME-$ENVIRONMENT:latest $ECR_REPO:latest
    docker push $ECR_REPO:latest
    
    cd ../..
    echo_info "Image pushed successfully"
}

# Update ECS service
update_service() {
    echo_info "Updating ECS service..."
    cd terraform
    
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
    SERVICE_NAME=$(terraform output -raw ecs_service_name)
    
    cd ..
    
    # Force new deployment
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --force-new-deployment \
        --region $AWS_REGION
    
    echo_info "Service update initiated"
}

# Configure demo user with permanent password
configure_demo_user() {
    echo_info "Configuring demo user with permanent password..."
    
    cd terraform
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
    CLIENT_ID=$(terraform output -raw cognito_client_id)
    APP_URL=$(terraform output -raw application_url)
    cd ..
    
    # Set permanent password for demo user
    aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "demouser" \
        --password "demo123" \
        --permanent \
        --region "$AWS_REGION" || {
        echo_warn "Failed to set permanent password for demo user (user might not exist yet)"
    }
    
    # Update Cognito User Pool Client with callback URLs (localhost only for now)
    echo_info "Updating Cognito callback URLs..."
    aws cognito-idp update-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-id "$CLIENT_ID" \
        --callback-urls "http://localhost:3000/api/auth/callback/cognito" "https://localhost:3000/api/auth/callback/cognito" \
        --logout-urls "http://localhost:3000/auth/signin" "https://localhost:3000/auth/signin" \
        --allowed-o-auth-flows "code" \
        --allowed-o-auth-flows-user-pool-client \
        --allowed-o-auth-scopes "email" "openid" "profile" \
        --supported-identity-providers "COGNITO" \
        --explicit-auth-flows "ALLOW_USER_SRP_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" \
        --prevent-user-existence-errors "ENABLED" \
        --region "$AWS_REGION" || {
        echo_warn "Failed to update callback URLs"
    }
    
    echo_warn "Note: Production ALB access requires HTTPS configuration"
    echo_info "For production use, configure SSL certificate on ALB and update callback URLs"
    
    echo_info "Demo user and callback URLs configured successfully"
}

# Save environment variables to .env.local for local development
save_env_vars() {
    echo_info "Saving environment variables to .env.local for local development..."
    
    cd terraform
    
    # Get values from Terraform outputs
    APP_URL=$(terraform output -raw application_url)
    COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)
    COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
    COGNITO_DOMAIN=$(terraform output -raw cognito_domain)
    CHAT_API_ENDPOINT=$(terraform output -raw chat_api_endpoint)
    
    cd ..
    
    # Get client secret from SSM
    echo_info "Retrieving Cognito client secret from AWS SSM..."
    COGNITO_CLIENT_SECRET=$(aws ssm get-parameter \
        --name "/$PROJECT_NAME-$ENVIRONMENT/cognito/client-secret" \
        --with-decryption \
        --region "$AWS_REGION" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null) || {
        echo_error "Failed to retrieve client secret from SSM"
        COGNITO_CLIENT_SECRET="get-from-aws-console-or-ssm"
    }
    
    # Create or update .env.local
    ENV_FILE="front/bf_traveler/.env.local"
    
    # Backup existing .env.local if it exists
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        echo_info "Backed up existing .env.local"
    fi
    
    # Create new .env.local with complete Cognito configuration
    cat > "$ENV_FILE" << EOF
# NextAuth Configuration
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-key-here-change-in-production

# Cognito Configuration (Auto-generated from Terraform)
COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID
COGNITO_CLIENT_SECRET=$COGNITO_CLIENT_SECRET
COGNITO_ISSUER=https://cognito-idp.$AWS_REGION.amazonaws.com/$COGNITO_USER_POOL_ID

# Chat API Configuration (Auto-generated from Terraform)
NEXT_PUBLIC_CHAT_API_ENDPOINT=$CHAT_API_ENDPOINT

# Production URLs (for reference)
# NEXTAUTH_URL=$APP_URL
# COGNITO_DOMAIN=https://$COGNITO_DOMAIN.auth.$AWS_REGION.amazoncognito.com
EOF
    
    echo_info "Environment variables saved to $ENV_FILE"
    
    if [ "$COGNITO_CLIENT_SECRET" = "get-from-aws-console-or-ssm" ]; then
        echo_warn "Note: COGNITO_CLIENT_SECRET could not be retrieved automatically"
        echo_info "You can get it manually with: aws ssm get-parameter --name '/$PROJECT_NAME-$ENVIRONMENT/cognito/client-secret' --with-decryption --region $AWS_REGION"
    else
        echo_info "All environment variables including COGNITO_CLIENT_SECRET have been set successfully"
    fi
}

# Deploy Lambda function
deploy_lambda() {
    echo_info "Packaging and deploying Lambda function..."

    cd lambda/chat_handler

    # Clean up previous package
    rm -f lambda_function.zip
    rm -rf .venv

    # Create deployment package using uv
    echo_info "Creating virtual environment and installing dependencies with uv..."
    uv venv
    source .venv/bin/activate
    uv pip install -r requirements.txt

    echo_info "Creating deployment zip..."
    # Create a temporary directory for packaging
    PACKAGE_DIR=$(mktemp -d -p .)

    # Install dependencies into the temporary directory using uv
    echo_info "Installing dependencies into temporary directory with uv..."
    uv pip install --python-platform linux --python 3.12 -r pyproject.toml --target "$PACKAGE_DIR"

    # Copy all Python source files and other necessary files to the package directory
    echo_info "Copying lambda function code and other local files to temporary directory..."
    find . -maxdepth 1 -name "*.py" -exec cp {} "$PACKAGE_DIR/" \;

    # Zip the contents of the package directory
    echo_info "Creating deployment zip from temporary directory..."
    cd "$PACKAGE_DIR"
    zip -r9 ../lambda_function.zip .
    cd - > /dev/null # Go back to the original directory (lambda/chat_handler)

    # Clean up the temporary directory
    echo_info "Cleaning up temporary directory..."
    rm -rf "$PACKAGE_DIR"
    deactivate

    # Get Lambda function name from Terraform output
    cd ../../terraform
    LAMBDA_FUNCTION_NAME=$(terraform output -raw lambda_function_name)
    cd ..

    # Update Lambda function code
    aws lambda update-function-code \
        --function-name $LAMBDA_FUNCTION_NAME \
        --zip-file fileb://lambda/chat_handler/lambda_function.zip \
        --region $AWS_REGION

    echo_info "Lambda function deployed successfully"
}

# Main deployment function
main() {
    if [ "$1" == "lambda" ]; then
        echo_info "Deploying Lambda function only..."
        check_dependencies
        deploy_lambda
        exit 0
    fi

    echo_info "Starting deployment of $PROJECT_NAME-$ENVIRONMENT"
    
    check_dependencies
    init_terraform
    deploy_infrastructure
    configure_demo_user
    build_and_push
    update_service
    save_env_vars
    
    cd terraform
    APP_URL=$(terraform output -raw application_url)
    COGNITO_DOMAIN=$(terraform output -raw cognito_hosted_ui_url)
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
    cd ..
    
    echo_info "Deployment completed successfully!"
    echo_info "Application URL: $APP_URL"
    echo_info "Cognito Hosted UI: $COGNITO_DOMAIN"
    echo_info "User Pool ID: $USER_POOL_ID"
    echo_warn "Note: It may take a few minutes for the service to be fully available"
    echo_warn "Demo user: Sign in with demo@example.com (password: demo123 - no change required)"
    echo_info "Use './scripts/manage-users.sh help' to manage Cognito users"
    echo_info "Local development environment variables saved to front/bf_traveler/.env.local"
}

# Run main function
main "$@"