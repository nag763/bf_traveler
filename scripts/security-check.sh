#!/bin/bash

# Security check script to detect potentially sensitive files
set -e

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

echo_info "Running security check for sensitive files..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo_error "Not in a git repository. Run this from the project root."
    exit 1
fi

# Files that should never be committed
SENSITIVE_FILES=(
    "terraform/terraform.tfvars"
    "terraform/*.tfstate"
    "terraform/*.tfstate.*"
    "front/bf_traveler/.env.local"
    ".env"
    ".env.local"
    "*.pem"
    "*.key"
    "*credentials*"
    "*secret*"
)

# Patterns to search for in committed files
SENSITIVE_PATTERNS=(
    "password.*="
    "secret.*="
    "key.*="
    "token.*="
    "AKIA[0-9A-Z]{16}"  # AWS Access Key pattern
    "aws_secret_access_key"
    "nextauth_secret.*="
)

ISSUES_FOUND=0

echo_info "Checking for sensitive files in git history..."

# Check if sensitive files are tracked by git
for pattern in "${SENSITIVE_FILES[@]}"; do
    if git ls-files | grep -q "$pattern" 2>/dev/null; then
        echo_error "Sensitive file pattern found in git: $pattern"
        git ls-files | grep "$pattern"
        ISSUES_FOUND=1
    fi
done

echo_info "Checking for sensitive patterns in committed files..."

# Check for sensitive patterns in committed files
for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if git grep -i "$pattern" 2>/dev/null | grep -v ".gitignore" | grep -v "security-check.sh" | grep -v ".example" | grep -v "README.md" | grep -v "SECURITY.md"; then
        echo_error "Sensitive pattern found: $pattern"
        ISSUES_FOUND=1
    fi
done

echo_info "Checking .gitignore coverage..."

# Check if .gitignore exists and has key patterns
if [ ! -f ".gitignore" ]; then
    echo_error ".gitignore file not found!"
    ISSUES_FOUND=1
else
    # Check for essential patterns in .gitignore
    REQUIRED_PATTERNS=(
        "terraform/terraform.tfvars"
        "*.tfstate"
        ".env.local"
        "node_modules/"
    )
    
    for pattern in "${REQUIRED_PATTERNS[@]}"; do
        if ! grep -q "$pattern" .gitignore; then
            echo_warn ".gitignore missing pattern: $pattern"
        fi
    done
fi

echo_info "Checking for untracked sensitive files..."

# Check for untracked sensitive files
if [ -f "terraform/terraform.tfvars" ]; then
    if git status --porcelain | grep -q "terraform.tfvars"; then
        echo_error "terraform.tfvars is not ignored by git!"
        ISSUES_FOUND=1
    fi
fi

if [ -f "front/bf_traveler/.env.local" ]; then
    if git status --porcelain | grep -q ".env.local"; then
        echo_error ".env.local is not ignored by git!"
        ISSUES_FOUND=1
    fi
fi

# Summary
echo
if [ $ISSUES_FOUND -eq 0 ]; then
    echo_info "✅ Security check passed! No sensitive files or patterns detected."
else
    echo_error "❌ Security issues found! Please review and fix the issues above."
    echo_warn "If sensitive data was already committed:"
    echo_warn "1. Remove the files from git: git rm --cached <file>"
    echo_warn "2. Add to .gitignore"
    echo_warn "3. Consider rotating any exposed secrets"
    echo_warn "4. For git history cleanup, consider using git filter-branch or BFG Repo-Cleaner"
    exit 1
fi