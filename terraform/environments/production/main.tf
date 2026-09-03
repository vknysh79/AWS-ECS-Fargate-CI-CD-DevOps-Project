module "vpc" {
  source               = "../../modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment
}

module "ecs_app" {
  source             = "../../modules/ecs-app"
  aws_region         = var.aws_region
  environment        = var.environment
  app_name           = var.app_name
  container_port     = var.container_port
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_count      = var.desired_count
  enable_blue_green  = true
}

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = module.ecs_app.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR Repository URL"
  value       = module.ecs_app.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = module.ecs_app.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS Service Name"
  value       = module.ecs_app.ecs_service_name
}
