# Security Guidelines

## Overview
This document outlines security best practices and guidelines for the BF Traveler application.

## Sensitive Files and Data Protection

### Files That Should NEVER Be Committed
- `terraform/terraform.tfvars` - Contains infrastructure secrets
- `terraform/*.tfstate*` - Contains sensitive infrastructure state
- `front/bf_traveler/.env.local` - Contains application secrets
- Any files containing AWS credentials, API keys, or passwords

### Environment Variables
- Always use `.env.example` as a template
- Generate strong secrets using: `openssl rand -base64 32`
- Rotate secrets regularly in production
- Use AWS Systems Manager Parameter Store for production secrets

### AWS Cognito Security
- User self-registration is disabled by design
- Only administrators can create new users
- Advanced security features are enabled (risk detection, etc.)
- Strong password policy is enforced
- Multi-factor authentication is supported

### Infrastructure Security
- ECS tasks run in private subnets
- Security groups follow principle of least privilege
- ALB handles public traffic with proper health checks
- Container images are scanned for vulnerabilities

## Development Security Practices

### Local Development
1. Never commit `.env.local` files
2. Use the provided scripts to manage secrets safely
3. Regularly update dependencies for security patches
4. Use HTTPS in production (configure ALB with SSL certificate)

### Deployment Security
1. Use unique, strong secrets for each environment
2. Regularly rotate AWS access keys
3. Monitor CloudWatch logs for suspicious activity
4. Keep Terraform state files secure and encrypted

### User Management
1. Use the provided user management scripts
2. Regularly audit user access
3. Disable unused accounts promptly
4. Monitor authentication logs

## Incident Response
If you suspect a security breach:
1. Immediately rotate all secrets and credentials
2. Review CloudWatch logs for suspicious activity
3. Disable affected user accounts
4. Update security groups if necessary
5. Document the incident and lessons learned

## Security Checklist

### Before Deployment
- [ ] Updated `terraform.tfvars` with strong secrets
- [ ] Verified `.env.local` is in `.gitignore`
- [ ] Confirmed no sensitive data in version control
- [ ] Reviewed security group rules
- [ ] Enabled CloudWatch logging

### After Deployment
- [ ] Verified HTTPS is working (if SSL configured)
- [ ] Tested authentication flow
- [ ] Confirmed user creation restrictions
- [ ] Monitored initial logs for errors
- [ ] Documented access credentials securely

### Regular Maintenance
- [ ] Rotate secrets quarterly
- [ ] Review user access monthly
- [ ] Update dependencies regularly
- [ ] Monitor security advisories
- [ ] Backup Terraform state securely

## Contact
For security concerns or questions, contact your system administrator.