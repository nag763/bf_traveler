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
BLUE='\033[0;34m'
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

echo_header() {
    echo -e "${BLUE}[COGNITO]${NC} $1"
}

# Get User Pool ID from Terraform output
get_user_pool_id() {
    cd terraform
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
    cd ..
    
    if [ -z "$USER_POOL_ID" ]; then
        echo_error "Could not get User Pool ID. Make sure Terraform has been applied."
        exit 1
    fi
    
    echo "$USER_POOL_ID"
}

# Create a new user
create_user() {
    local email=$1
    local temp_password=$2
    
    if [ -z "$email" ] || [ -z "$temp_password" ]; then
        echo_error "Usage: create_user <email> <temporary_password>"
        return 1
    fi
    
    USER_POOL_ID=$(get_user_pool_id)
    
    # Generate a username from email (remove @ and . for Cognito compatibility)
    local username=$(echo "$email" | sed 's/@/_at_/g' | sed 's/\./_dot_/g')
    
    echo_info "Creating user with email: $email"
    echo_info "Generated username: $username"
    
    aws cognito-idp admin-create-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$username" \
        --user-attributes Name=email,Value="$email" Name=email_verified,Value=true \
        --temporary-password "$temp_password" \
        --message-action SUPPRESS \
        --region "$AWS_REGION"
    
    echo_info "User created successfully!"
    echo_info "Email: $email (use this to sign in)"
    echo_info "Username: $username (internal Cognito username)"
    echo_warn "Temporary password: $temp_password"
    echo_warn "User must change password on first login"
}

# List all users
list_users() {
    USER_POOL_ID=$(get_user_pool_id)
    
    echo_header "Users in Cognito User Pool:"
    
    aws cognito-idp list-users \
        --user-pool-id "$USER_POOL_ID" \
        --region "$AWS_REGION" \
        --query 'Users[*].{Username:Username,Email:Attributes[?Name==`email`].Value|[0],Status:UserStatus,Created:UserCreateDate}' \
        --output table
}

# Delete a user
delete_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo_error "Usage: delete_user <username>"
        return 1
    fi
    
    USER_POOL_ID=$(get_user_pool_id)
    
    echo_warn "Deleting user: $username"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws cognito-idp admin-delete-user \
            --user-pool-id "$USER_POOL_ID" \
            --username "$username" \
            --region "$AWS_REGION"
        
        echo_info "User deleted successfully!"
    else
        echo_info "Operation cancelled"
    fi
}

# Reset user password
reset_password() {
    local username=$1
    local new_temp_password=$2
    
    if [ -z "$username" ] || [ -z "$new_temp_password" ]; then
        echo_error "Usage: reset_password <username> <new_temporary_password>"
        return 1
    fi
    
    USER_POOL_ID=$(get_user_pool_id)
    
    echo_info "Resetting password for user: $username"
    
    aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "$username" \
        --password "$new_temp_password" \
        --temporary \
        --region "$AWS_REGION"
    
    echo_info "Password reset successfully!"
    echo_warn "Temporary password: $new_temp_password"
    echo_warn "User must change password on next login"
}

# Enable user
enable_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo_error "Usage: enable_user <username>"
        return 1
    fi
    
    USER_POOL_ID=$(get_user_pool_id)
    
    echo_info "Enabling user: $username"
    
    aws cognito-idp admin-enable-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$username" \
        --region "$AWS_REGION"
    
    echo_info "User enabled successfully!"
}

# Disable user
disable_user() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo_error "Usage: disable_user <username>"
        return 1
    fi
    
    USER_POOL_ID=$(get_user_pool_id)
    
    echo_warn "Disabling user: $username"
    
    aws cognito-idp admin-disable-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$username" \
        --region "$AWS_REGION"
    
    echo_info "User disabled successfully!"
}

# Show help
show_help() {
    echo_header "Cognito User Management Script"
    echo
    echo "Usage: $0 <command> [arguments]"
    echo
    echo "Commands:"
    echo "  create <email> <temp_password>    Create a new user"
    echo "  list                              List all users"
    echo "  delete <username>                 Delete a user (use internal username)"
    echo "  reset <username> <temp_password>  Reset user password (use internal username)"
    echo "  enable <username>                 Enable a user (use internal username)"
    echo "  disable <username>                Disable a user (use internal username)"
    echo "  help                              Show this help"
    echo
    echo "Examples:"
    echo "  $0 create john@example.com TempPass123!"
    echo "  $0 list"
    echo "  $0 reset john_at_example_dot_com NewTemp456!"
    echo "  $0 delete john_at_example_dot_com"
    echo
    echo "Note: Users sign in with their email address, but Cognito uses internal usernames."
    echo "      Use 'list' command to see the internal usernames for management operations."
}

# Main script logic
case "$1" in
    "create")
        create_user "$2" "$3"
        ;;
    "list")
        list_users
        ;;
    "delete")
        delete_user "$2"
        ;;
    "reset")
        reset_password "$2" "$3"
        ;;
    "enable")
        enable_user "$2"
        ;;
    "disable")
        disable_user "$2"
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