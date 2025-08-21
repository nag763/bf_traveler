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

# Setup local environment for development
setup_local_env() {
    echo_info "Setting up local development environment..."
    
    ENV_FILE="front/bf_traveler/.env.local"
    
    if [ ! -f "$ENV_FILE" ]; then
        echo_error ".env.local file not found. Please run ./deploy.sh first to create the infrastructure."
        exit 1
    fi
    
    echo_info "Getting Cognito configuration from Terraform and AWS SSM..."
    
    # Get values from Terraform outputs
    cd terraform
    COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null)
    COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
    CHAT_API_ENDPOINT=$(terraform output -raw chat_api_endpoint 2>/dev/null)
    cd ..
    
    # Get client secret from SSM
    CLIENT_SECRET=$(aws ssm get-parameter \
        --name "/$PROJECT_NAME-$ENVIRONMENT/cognito/client-secret" \
        --with-decryption \
        --region "$AWS_REGION" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null)
    
    if [ -z "$CLIENT_SECRET" ]; then
        echo_error "Could not retrieve client secret. Make sure you have deployed the infrastructure and have proper AWS credentials."
        exit 1
    fi
    
    # Update all Cognito and API-related environment variables
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/COGNITO_CLIENT_ID=.*/COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID/" "$ENV_FILE"
        sed -i '' "s/COGNITO_CLIENT_SECRET=.*/COGNITO_CLIENT_SECRET=$CLIENT_SECRET/" "$ENV_FILE"
        sed -i '' "s|COGNITO_ISSUER=.*|COGNITO_ISSUER=https://cognito-idp.$AWS_REGION.amazonaws.com/$COGNITO_USER_POOL_ID|" "$ENV_FILE"
        sed -i '' "s|NEXT_PUBLIC_CHAT_API_ENDPOINT=.*|NEXT_PUBLIC_CHAT_API_ENDPOINT=$CHAT_API_ENDPOINT|" "$ENV_FILE"
    else
        # Linux
        sed -i "s/COGNITO_CLIENT_ID=.*/COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID/" "$ENV_FILE"
        sed -i "s/COGNITO_CLIENT_SECRET=.*/COGNITO_CLIENT_SECRET=$CLIENT_SECRET/" "$ENV_FILE"
        sed -i "s|COGNITO_ISSUER=.*|COGNITO_ISSUER=https://cognito-idp.$AWS_REGION.amazonaws.com/$COGNITO_USER_POOL_ID|" "$ENV_FILE"
        sed -i "s|NEXT_PUBLIC_CHAT_API_ENDPOINT=.*|NEXT_PUBLIC_CHAT_API_ENDPOINT=$CHAT_API_ENDPOINT|" "$ENV_FILE"
    fi
    
    echo_info "Updated all Cognito configuration in $ENV_FILE"
    echo_info "Local development environment setup complete!"
    echo_info "You can now run 'npm run dev' in the front/bf_traveler directory"
}

# Show current environment configuration
show_config() {
    echo_info "Current environment configuration:"
    
    ENV_FILE="front/bf_traveler/.env.local"
    
    if [ ! -f "$ENV_FILE" ]; then
        echo_error ".env.local file not found"
        return 1
    fi
    
    echo
    echo "=== .env.local contents ==="
    # Show file contents but mask sensitive values
    while IFS= read -r line; do
        if [[ $line == *"SECRET"* ]] || [[ $line == *"PASSWORD"* ]]; then
            key=$(echo "$line" | cut -d'=' -f1)
            echo "$key=***MASKED***"
        else
            echo "$line"
        fi
    done < "$ENV_FILE"
    echo "=========================="
    echo
}

# Show help
show_help() {
    echo_info "Local Environment Setup Script"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  setup     Setup local development environment with Cognito client secret"
    echo "  show      Show current environment configuration (secrets masked)"
    echo "  help      Show this help"
    echo
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 show"
}

# Main script logic
case "$1" in
    "setup")
        setup_local_env
        ;;
    "show")
        show_config
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac