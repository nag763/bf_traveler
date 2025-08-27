# BF Traveler - Authenticated Chat Application

## Foreword

This project was created as a demonstration to showcase how AI agents and tools work together in modern software development. The BF Traveler application serves as a practical example of integrating various technologies including AWS services, authentication systems, and chat interfaces, while demonstrating the power of agent-driven development workflows.

The project illustrates how agents can orchestrate complex deployments, manage infrastructure as code, and handle sophisticated authentication flows - all while maintaining security best practices and providing a seamless user experience.

## Overview

A Next.js application with authentication and chat interface, deployed on AWS ECS with Fargate.

## Features

- **AWS Cognito Authentication**: Secure login system with AWS Cognito User Pool
- **Admin-Only User Creation**: Users cannot self-register, only admins can create accounts
- **Chat Interface**: Real-time chat interface with message history
- **Responsive Design**: Mobile-friendly UI built with Tailwind CSS
- **Cloud Deployment**: Containerized deployment on AWS ECS/Fargate
- **Infrastructure as Code**: Complete Terraform configuration with Cognito integration

## Architecture

### System Architecture Diagram

```mermaid
graph TB
    subgraph "User Layer"
        U[User Browser]
    end
    
    subgraph "AWS Cloud - VPC (10.0.0.0/16)"
        subgraph "Public Subnets (AZ1 & AZ2)"
            ALB[Application Load Balancer<br/>Port 80/443]
            NAT1[NAT Gateway AZ1]
            NAT2[NAT Gateway AZ2]
            IGW[Internet Gateway]
        end
        
        subgraph "Private Subnets (AZ1 & AZ2)"
            subgraph "ECS Fargate Cluster"
                T1[ECS Task 1<br/>Next.js App<br/>Port 3000]
                T2[ECS Task 2<br/>Next.js App<br/>Port 3000]
            end
        end
        
        subgraph "Serverless Layer"
            APIGW[API Gateway<br/>Regional Endpoint]
            LC[Chat Handler Lambda<br/>Python 3.12]
            LM[MCP Handler Lambda<br/>Node.js 22.x]
        end
        
        subgraph "AWS Managed Services"
            ECR[Elastic Container Registry<br/>Image Storage]
            CW[CloudWatch Logs<br/>Centralized Logging]
            SSM[Systems Manager<br/>Parameter Store<br/>Secrets Management]
            COGNITO[AWS Cognito<br/>User Pool + Client<br/>OAuth 2.0]
            BEDROCK[Amazon Bedrock<br/>AI Models]
        end
    end
    
    subgraph "External Services"
        GH[GitHub Repository<br/>Source Code]
    end
    
    %% User flow
    U -->|HTTP/HTTPS| ALB
    ALB -->|Health Check & Load Balance| T1
    ALB -->|Health Check & Load Balance| T2
    
    %% Internet connectivity
    IGW -->|Internet Access| ALB
    T1 -->|Outbound via| NAT1
    T2 -->|Outbound via| NAT2
    NAT1 -->|Internet Access| IGW
    NAT2 -->|Internet Access| IGW
    
    %% Application authentication
    T1 -->|NextAuth.js| COGNITO
    T2 -->|NextAuth.js| COGNITO
    
    %% API Gateway integration
    T1 -->|Chat API Calls| APIGW
    T2 -->|Chat API Calls| APIGW
    APIGW -->|/chat endpoint<br/>Cognito Auth| LC
    APIGW -->|/mcp endpoint<br/>No Auth| LM
    
    %% Lambda interactions
    LC -->|Invoke AI Models| BEDROCK
    LC -->|Call MCP Functions| LM
    LM -->|User Context| COGNITO
    
    %% Infrastructure services
    T1 -->|Pull Container Images| ECR
    T2 -->|Pull Container Images| ECR
    T1 -->|Application Logs| CW
    T2 -->|Application Logs| CW
    LC -->|Function Logs| CW
    LM -->|Function Logs| CW
    APIGW -->|Access Logs| CW
    
    %% Secrets and configuration
    T1 -->|Get Secrets<br/>(NextAuth, Cognito)| SSM
    T2 -->|Get Secrets<br/>(NextAuth, Cognito)| SSM
    LC -->|Get Configuration| SSM
    LM -->|Get Configuration| SSM
    
    %% CI/CD pipeline
    GH -->|Docker Build & Push| ECR
    
    %% Security Groups
    T1 -.->|Port 3000 from ALB| T1
    T2 -.->|Port 3000 from ALB| T2
    
    %% Styling
    classDef aws fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    classDef user fill:#4285f4,stroke:#1a73e8,stroke-width:2px,color:#fff
    classDef app fill:#0f9d58,stroke:#137333,stroke-width:2px,color:#fff
    classDef external fill:#ea4335,stroke:#d33b2c,stroke-width:2px,color:#fff
    classDef network fill:#9aa0a6,stroke:#5f6368,stroke-width:2px,color:#fff
    
    class ALB,ECR,CW,SSM,COGNITO,APIGW,BEDROCK aws
    class U user
    class T1,T2,LC,LM app
    class GH external
    class IGW,NAT1,NAT2 network
```

### Architecture Components

#### Frontend Layer
- **Next.js Application**: React 19 with Next.js 15 framework
- **Authentication**: NextAuth.js with AWS Cognito OAuth 2.0 integration
- **Styling**: Tailwind CSS for responsive design
- **Container**: Docker multi-stage build for optimized production images

#### Infrastructure Layer
- **VPC**: Custom VPC (10.0.0.0/16) with public/private subnets across 2 AZs
- **Load Balancer**: Application Load Balancer with health checks and auto-scaling
- **Compute**: ECS Fargate cluster with auto-scaling (CPU-based)
- **Container Registry**: ECR with image scanning and lifecycle policies

#### API & Serverless Layer
- **API Gateway**: Regional REST API with CORS support
- **Chat Handler**: Python 3.12 Lambda with Bedrock AI integration
- **MCP Handler**: Node.js 22.x Lambda for Model Context Protocol operations
- **Authentication**: Cognito User Pool authorizer for secure endpoints

#### Security & Configuration
- **User Management**: AWS Cognito User Pool (admin-only user creation)
- **Secrets Management**: AWS Systems Manager Parameter Store for secure configuration
- **Network Security**: Security groups with minimal required access
- **Advanced Security**: Cognito advanced security features enabled

#### Monitoring & Logging
- **CloudWatch**: Centralized logging for all components
- **Health Checks**: ALB health checks with automatic failover
- **Container Insights**: ECS cluster monitoring enabled
- **API Logging**: API Gateway access logs and metrics

#### AI Integration
- **Amazon Bedrock**: AI model integration for chat functionality
- **MCP Protocol**: Model Context Protocol for structured AI interactions

## Prerequisites

- Node.js 18+
- Docker
- AWS CLI configured
- Terraform >= 1.0

## Important Security Note

This repository includes a comprehensive `.gitignore` file that excludes:

- Terraform state files (`*.tfstate`)
- Terraform variables (`terraform.tfvars`)
- Environment files (`.env.local`)
- AWS credentials and other sensitive data

**Never commit sensitive files to version control!** Use the provided `.env.example` as a template.

Run the security check before committing:

```bash
./scripts/security-check.sh
```

## Local Development

1. **Install dependencies**:

   ```bash
   cd front/bf_traveler
   npm install
   ```

2. **Set up environment variables**:

   ```bash
   cp .env.local.example .env.local
   # Update NEXTAUTH_SECRET with a secure random string
   ```

3. **Run development server**:

   ```bash
   npm run dev
   ```

4. **Set up Cognito for local development**:

   - The deployment script automatically updates `.env.local` with Cognito configuration
   - You'll need to manually add the `COGNITO_CLIENT_SECRET` from AWS Console or SSM

5. **Access the application**:
   - Open http://localhost:3000
   - Use demo credentials: `demo@example.com` / `TempPass123!` (must change on first login)

## Deployment

### Quick Deployment

1. **Configure Terraform variables**:

   ```bash
   # The terraform.tfvars file is already present, but you need to update the secret
   ./scripts/generate-secret.sh
   # Copy the generated secret and update terraform/terraform.tfvars

   # Or generate and update automatically:
   SECRET=$(openssl rand -base64 32)
   sed -i "s/nextauth_secret = \".*\"/nextauth_secret = \"$SECRET\"/" terraform/terraform.tfvars
   ```

2. **Run deployment script**:
   ```bash
   ./deploy.sh
   ```

### Manual Deployment

1. **Deploy infrastructure**:

   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

2. **Build and push Docker image**:

   ```bash
   # Get ECR repository URL from Terraform output
   ECR_REPO=$(terraform output -raw ecr_repository_url)

   # Login to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

   # Build and push
   cd ../front/bf_traveler
   docker build -t bf-traveler .
   docker tag bf-traveler:latest $ECR_REPO:latest
   docker push $ECR_REPO:latest
   ```

3. **Update ECS service**:
   ```bash
   aws ecs update-service \
     --cluster $(terraform output -raw ecs_cluster_name) \
     --service $(terraform output -raw ecs_service_name) \
     --force-new-deployment
   ```

## Configuration

### Environment Variables

- `NEXTAUTH_URL`: Application URL (set automatically in production)
- `NEXTAUTH_SECRET`: Secret key for NextAuth.js (stored in AWS SSM)

### Terraform Variables

| Variable          | Description          | Default        |
| ----------------- | -------------------- | -------------- |
| `aws_region`      | AWS region           | `eu-central-1` |
| `project_name`    | Project name         | `bf-traveler`  |
| `environment`     | Environment name     | `dev`          |
| `container_port`  | Container port       | `3000`         |
| `cpu`             | ECS task CPU units   | `256`          |
| `memory`          | ECS task memory (MB) | `512`          |
| `desired_count`   | Number of tasks      | `2`            |
| `nextauth_secret` | NextAuth secret key  | Required       |

## Infrastructure Components

- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **ALB**: Application Load Balancer for traffic distribution
- **ECS**: Fargate cluster with auto-scaling capabilities
- **ECR**: Container registry for Docker images
- **Cognito**: User Pool for authentication and user management
- **CloudWatch**: Centralized logging and monitoring
- **SSM**: Secure parameter storage for secrets and Cognito configuration

## Security Features

- Private subnets for ECS tasks
- Security groups with minimal required access
- Secrets stored in AWS Systems Manager
- Container image scanning enabled
- HTTPS-ready ALB configuration

## Monitoring

- CloudWatch logs for application monitoring
- ECS service metrics and health checks
- ALB health checks with automatic failover

## Security

This application follows security best practices:

- No self-registration (admin-only user creation)
- Secrets stored in AWS Systems Manager
- Private subnets for application containers
- Strong password policies enforced

**Important**: Never commit sensitive files to version control. See [SECURITY.md](SECURITY.md) for detailed security guidelines.

## Cleanup

### Automated Undeploy (Recommended)

Use the undeploy script for safe and complete cleanup:

```bash
# Interactive undeploy with confirmations
./undeploy.sh

# Force undeploy without confirmations (use with caution!)
./undeploy.sh --force
```

The undeploy script will:
- Clean up all Docker images from ECR
- Destroy all AWS infrastructure using Terraform
- Reset local environment files to templates
- Provide detailed summary of what was removed

### Manual Cleanup

To destroy resources manually:

```bash
cd terraform
terraform destroy
```

**Note**: Manual cleanup may leave ECR images and other resources that need separate cleanup.

## User Management

### Demo Account

A demo user is automatically created during deployment:

- **Sign-in Email**: `demo@example.com`
- **Temporary Password**: `TempPass123!`
- **Note**: Sign in using the email address, password must be changed on first login

### Managing Users

Use the provided script to manage Cognito users (see [Cognito Guide](docs/COGNITO_GUIDE.md) for details):

```bash
# Create a new user
./scripts/manage-users.sh create john@example.com TempPass123!

# List all users
./scripts/manage-users.sh list

# Reset user password
./scripts/manage-users.sh reset john@example.com NewTemp456!

# Disable/Enable users
./scripts/manage-users.sh disable john@example.com
./scripts/manage-users.sh enable john@example.com

# Delete a user
./scripts/manage-users.sh delete john@example.com
```

### Security Features

- **No Self-Registration**: Users cannot create their own accounts
- **Admin-Only User Creation**: Only administrators can create new users
- **Temporary Passwords**: All new users receive temporary passwords that must be changed
- **Advanced Security**: Cognito advanced security features enabled
- **Password Policy**: Strong password requirements enforced
- **Flexible Callback URLs**: No callback URL restrictions for development flexibility

> **Note**: This configuration is designed for development/demo environments. In production, configure specific callback URLs for enhanced security.

## Troubleshooting

### Common Issues

1. **ECS tasks failing to start**: Check CloudWatch logs for container errors
2. **ALB health checks failing**: Verify security group rules and container health
3. **Authentication not working**: Ensure NEXTAUTH_SECRET is properly set

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster <cluster-name> --services <service-name>

# View CloudWatch logs
aws logs tail /ecs/bf-traveler-dev --follow

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Get Cognito client secret for local development
aws ssm get-parameter --name '/bf-traveler-dev/cognito/client-secret' --with-decryption --region eu-central-1 --query 'Parameter.Value' --output text

# Update Cognito callback URLs (done automatically during deployment)
./scripts/update-cognito-urls.sh update

# Show current Cognito configuration
./scripts/update-cognito-urls.sh show
```

### Local Development Setup

After running `./deploy.sh`, your `.env.local` file will be automatically updated with most Cognito configuration. To complete the setup:

```bash
# Use the helper script to automatically get and set the client secret
./scripts/setup-local-env.sh setup

# Or manually get the client secret
CLIENT_SECRET=$(aws ssm get-parameter --name '/bf-traveler-dev/cognito/client-secret' --with-decryption --region eu-central-1 --query 'Parameter.Value' --output text)
echo "COGNITO_CLIENT_SECRET=$CLIENT_SECRET" >> front/bf_traveler/.env.local
```

You can also check your current environment configuration:

```bash
./scripts/setup-local-env.sh show
```
