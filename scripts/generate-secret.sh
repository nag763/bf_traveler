#!/bin/bash

# Generate a secure random string for NextAuth secret
echo "Generating secure NextAuth secret..."
echo
SECRET=$(openssl rand -base64 32)
echo "Generated secret: $SECRET"
echo
echo "Copy this value and update the 'nextauth_secret' in terraform/terraform.tfvars"
echo
echo "You can also run this command to update it automatically:"
echo "sed -i 's/nextauth_secret = \".*\"/nextauth_secret = \"$SECRET\"/' terraform/terraform.tfvars"