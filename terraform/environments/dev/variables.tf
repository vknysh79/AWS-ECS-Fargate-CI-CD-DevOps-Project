variable "aws_region" {
  type        = string
  description = "AWS Region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
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

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs"
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs"
  default     = ["10.1.10.0/24", "10.1.20.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "desired_count" {
  type        = number
  description = "Desired number of container instances"
  default     = 1
}
