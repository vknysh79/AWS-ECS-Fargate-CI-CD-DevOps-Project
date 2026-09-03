output "alb_dns_name" {
  description = "Application Load Balancer DNS endpoint"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "Amazon ECR Repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Amazon ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Amazon ECS Service name"
  value       = aws_ecs_service.app.name
}

output "target_group_blue_arn" {
  description = "Blue/Primary Target Group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  description = "Green Target Group ARN (Production only)"
  value       = var.enable_blue_green ? aws_lb_target_group.green[0].arn : null
}

output "prod_listener_arn" {
  description = "Production ALB Listener ARN"
  value       = aws_lb_listener.http_prod.arn
}

output "test_listener_arn" {
  description = "Test ALB Listener ARN (Production only)"
  value       = var.enable_blue_green ? aws_lb_listener.http_test[0].arn : null
}
