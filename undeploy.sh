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

echo_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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
    
    echo_info "All dependencies are installed"
}

# Confirm destruction with user
confirm_destruction() {
    echo_warn "⚠️  WARNING: This will completely destroy the following infrastructure:"
    echo "   - ECS Cluster and Service"
    echo "   - Application Load Balancer"
    echo "   - ECR Repository (and all Docker images)"
    echo "   - Lambda Functions"
    echo "   - API Gateway"
    echo "   - Cognito User Pool (and all users)"
    echo "   - VPC, Subnets, and Networking"
    echo "   - All SSM Parameters"
    echo "   - CloudWatch Log Groups"
    echo
    echo_warn "This action is IRREVERSIBLE!"
    echo
    
    read -p "Are you sure you want to proceed? Type 'yes' to continue: " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo_info "Undeploy cancelled by user"
        exit 0
    fi
    
    echo_warn "Final confirmation required!"
    read -p "Type the project name '$PROJECT_NAME' to confirm destruction: " project_confirmation
    
    if [ "$project_confirmation" != "$PROJECT_NAME" ]; then
        echo_error "Project name confirmation failed. Undeploy cancelled."
        exit 1
    fi
    
    echo_info "Destruction confirmed. Proceeding..."
}

# Clean up ECR repository images
cleanup_ecr_images() {
    echo_step "Cleaning up ECR repository images..."
    
    cd terraform
    
    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        echo_warn "No Terraform state found. Skipping ECR cleanup."
        cd ..
        return
    fi
    
    # Get ECR repository name from Terraform output
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    
    if [ -n "$ECR_REPO_URL" ]; then
        ECR_REPO_NAME=$(echo "$ECR_REPO_URL" | cut -d'/' -f2)
        
        echo_info "Deleting all images from ECR repository: $ECR_REPO_NAME"
        
        # List and delete all images
        IMAGE_TAGS=$(aws ecr list-images \
            --repository-name "$ECR_REPO_NAME" \
            --region "$AWS_REGION" \
            --query 'imageIds[*].imageTag' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$IMAGE_TAGS" ] && [ "$IMAGE_TAGS" != "None" ]; then
            for tag in $IMAGE_TAGS; do
                echo_info "Deleting image with tag: $tag"
                aws ecr batch-delete-image \
                    --repository-name "$ECR_REPO_NAME" \
                    --image-ids imageTag="$tag" \
                    --region "$AWS_REGION" >/dev/null 2>&1 || true
            done
        fi
        
        # Delete untagged images
        UNTAGGED_IMAGES=$(aws ecr list-images \
            --repository-name "$ECR_REPO_NAME" \
            --region "$AWS_REGION" \
            --filter tagStatus=UNTAGGED \
            --query 'imageIds[*].imageDigest' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$UNTAGGED_IMAGES" ] && [ "$UNTAGGED_IMAGES" != "None" ]; then
            for digest in $UNTAGGED_IMAGES; do
                echo_info "Deleting untagged image: $digest"
                aws ecr batch-delete-image \
                    --repository-name "$ECR_REPO_NAME" \
                    --image-ids imageDigest="$digest" \
                    --region "$AWS_REGION" >/dev/null 2>&1 || true
            done
        fi
        
        echo_info "ECR repository cleanup completed"
    else
        echo_warn "Could not determine ECR repository name. Skipping ECR cleanup."
    fi
    
    cd ..
}

# Destroy infrastructure with Terraform
destroy_infrastructure() {
    echo_step "Destroying infrastructure with Terraform..."
    
    cd terraform
    
    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        echo_warn "No Terraform state found. Nothing to destroy."
        cd ..
        return
    fi
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        echo_info "Initializing Terraform..."
        terraform init
    fi
    
    # Show what will be destroyed
    echo_info "Planning destruction..."
    terraform plan -destroy
    
    echo_warn "Proceeding with destruction in 5 seconds..."
    sleep 5
    
    # Destroy infrastructure
    echo_info "Destroying infrastructure..."
    terraform destroy -auto-approve
    
    cd ..
    
    echo_info "Infrastructure destruction completed"
}

# Clean up local files
cleanup_local_files() {
    echo_step "Cleaning up local files..."
    
    # Backup and remove .env.local
    if [ -f "front/bf_traveler/.env.local" ]; then
        cp "front/bf_traveler/.env.local" "front/bf_traveler/.env.local.backup.$(date +%Y%m%d_%H%M%S)"
        echo_info "Backed up .env.local"
        
        # Reset .env.local to example template
        cp "front/bf_traveler/.env.example" "front/bf_traveler/.env.local"
        echo_info "Reset .env.local to template"
    fi
    
    # Clean up Terraform state backups (optional)
    read -p "Do you want to remove Terraform state backup files? (y/N): " cleanup_tf_backups
    if [[ $cleanup_tf_backups =~ ^[Yy]$ ]]; then
        rm -f terraform/terraform.tfstate.backup*
        echo_info "Removed Terraform state backup files"
    fi
    
    echo_info "Local cleanup completed"
}

# Show summary
show_summary() {
    echo_step "Undeploy Summary"
    echo_info "✅ Infrastructure destroyed successfully"
    echo_info "✅ ECR images cleaned up"
    echo_info "✅ Local files reset"
    echo
    echo_warn "What was removed:"
    echo "   - All AWS infrastructure (ECS, ALB, Lambda, API Gateway, VPC, Cognito, etc.)"
    echo "   - All Docker images from ECR"
    echo "   - All SSM parameters"
    echo "   - All CloudWatch logs"
    echo
    echo_info "What was preserved:"
    echo "   - Source code and configuration files"
    echo "   - Terraform configuration files"
    echo "   - Backup of previous .env.local"
    echo
    echo_info "To redeploy, simply run: ./deploy.sh"
}

# Show help
show_help() {
    echo_info "Infrastructure Undeploy Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --force     Skip confirmation prompts (use with caution!)"
    echo "  --help      Show this help"
    echo
    echo "This script will:"
    echo "  1. Clean up all Docker images from ECR"
    echo "  2. Destroy all AWS infrastructure using Terraform"
    echo "  3. Reset local environment files"
    echo
    echo "⚠️  WARNING: This action is irreversible!"
}

# Main undeploy function
main() {
    echo_info "Starting undeploy of $PROJECT_NAME-$ENVIRONMENT"
    echo
    
    # Parse command line arguments
    FORCE_MODE=false
    
    for arg in "$@"; do
        case $arg in
            --force)
                FORCE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo_error "Unknown option: $arg"
                show_help
                exit 1
                ;;
        esac
    done
    
    check_dependencies
    
    if [ "$FORCE_MODE" = false ]; then
        confirm_destruction
    else
        echo_warn "Running in force mode - skipping confirmations"
    fi
    
    cleanup_ecr_images
    destroy_infrastructure
    cleanup_local_files
    show_summary
    
    echo_info "Undeploy completed successfully!"
}

# Run main function
main "$@"