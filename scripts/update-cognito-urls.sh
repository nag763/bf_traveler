#!/bin/bash

# NOTE: This script is no longer required for the main deployment
# The Cognito User Pool is configured without callback URL restrictions
# This script is kept for reference and production use cases

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

# Update Cognito callback URLs with actual ALB DNS name
update_cognito_urls() {
    echo_info "Updating Cognito callback URLs with ALB DNS name..."
    
    # Get values from Terraform outputs
    cd terraform
    
    if [ ! -f "terraform.tfstate" ]; then
        echo_error "Terraform state not found. Please run terraform apply first."
        exit 1
    fi
    
    ALB_DNS_NAME=$(terraform output -raw alb_dns_name 2>/dev/null)
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
    CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null)
    
    cd ..
    
    if [ -z "$ALB_DNS_NAME" ] || [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ]; then
        echo_error "Could not get required values from Terraform outputs"
        exit 1
    fi
    
    echo_info "ALB DNS Name: $ALB_DNS_NAME"
    echo_info "User Pool ID: $USER_POOL_ID"
    echo_info "Client ID: $CLIENT_ID"
    
    # Update callback URLs (pass as separate parameters)
    CALLBACK_URL_LOCAL_HTTP="http://localhost:3000/api/auth/callback/cognito"
    CALLBACK_URL_LOCAL_HTTPS="https://localhost:3000/api/auth/callback/cognito"
    # Note: Cognito requires HTTPS for production URLs, so we'll skip ALB URL for now
    # CALLBACK_URL_ALB="https://$ALB_DNS_NAME/api/auth/callback/cognito"  # Requires SSL certificate
    LOGOUT_URL_LOCAL_HTTP="http://localhost:3000/auth/signin"
    LOGOUT_URL_LOCAL_HTTPS="https://localhost:3000/auth/signin"
    # LOGOUT_URL_ALB="https://$ALB_DNS_NAME/auth/signin"  # Requires SSL certificate
    
    echo_info "Updating Cognito User Pool Client with new URLs..."
    
    aws cognito-idp update-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-id "$CLIENT_ID" \
        --callback-urls "$CALLBACK_URL_LOCAL_HTTP" "$CALLBACK_URL_LOCAL_HTTPS" \
        --logout-urls "$LOGOUT_URL_LOCAL_HTTP" "$LOGOUT_URL_LOCAL_HTTPS" \
        --allowed-o-auth-flows "code" \
        --allowed-o-auth-scopes "email" "openid" "profile" \
        --explicit-auth-flows "ALLOW_USER_SRP_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" \
        --allowed-o-auth-flows-user-pool-client \
        --supported-identity-providers "COGNITO" \
        --prevent-user-existence-errors "ENABLED" \
        --region "$AWS_REGION"
    
    echo_info "Cognito callback URLs updated successfully!"
    echo_info "Callback URLs: $CALLBACK_URL_LOCAL_HTTP, $CALLBACK_URL_LOCAL_HTTPS"
    echo_info "Logout URLs: $LOGOUT_URL_LOCAL_HTTP, $LOGOUT_URL_LOCAL_HTTPS"
    echo_warn "Note: Production ALB URLs require HTTPS/SSL certificate configuration"
}

# Show current Cognito configuration
show_cognito_config() {
    echo_info "Current Cognito configuration:"
    
    cd terraform
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
    CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null)
    cd ..
    
    if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ]; then
        echo_error "Could not get Cognito configuration from Terraform outputs"
        exit 1
    fi
    
    aws cognito-idp describe-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-id "$CLIENT_ID" \
        --region "$AWS_REGION" \
        --query 'UserPoolClient.{CallbackURLs:CallbackURLs,LogoutURLs:LogoutURLs}' \
        --output table
}

# Show help
show_help() {
    echo_info "Cognito URL Update Script"
    echo
    echo "NOTE: This script is no longer required for the main deployment."
    echo "The Cognito User Pool is configured without callback URL restrictions."
    echo "This script is kept for reference and production use cases."
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  update    Update Cognito callback URLs with ALB DNS name (for production)"
    echo "  show      Show current Cognito callback URLs configuration"
    echo "  help      Show this help"
    echo
    echo "Examples:"
    echo "  $0 update"
    echo "  $0 show"
}

# Main script logic
case "$1" in
    "update")
        update_cognito_urls
        ;;
    "show")
        show_cognito_config
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