variable "aws_region" {
  type        = string
  description = "AWS Region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "enable_blue_green" {
  type        = bool
  description = "Enable dual target groups (Blue/Green) and test listener (for production environment only)"
  default     = false
}

variable "app_name" {
  type        = string
  description = "Application name"
  default     = "devops-app"
}

variable "container_port" {
  type        = number
  description = "Container port for application"
  default     = 5000
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources are deployed"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB placement"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS task placement"
}

variable "desired_count" {
  type        = number
  description = "Desired number of ECS task instances"
  default     = 2
}

variable "fargate_cpu" {
  type        = string
  description = "CPU units for Fargate task definition"
  default     = "256"
}

variable "fargate_memory" {
  type        = string
  description = "Memory (in MB) for Fargate task definition"
  default     = "512"
}

