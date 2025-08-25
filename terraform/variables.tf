variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "bf-traveler"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "container_port" {
  description = "Port on which the container runs"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory for the task"
  type        = number
  default     = 512
}

variable "min_capacity" {
  description = "Minimum number of tasks for ECS service auto-scaling"
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Maximum number of tasks for ECS service auto-scaling"
  type        = number
  default     = 4
}

variable "nextauth_secret" {
  description = "NextAuth secret key"
  type        = string
  sensitive   = true
}