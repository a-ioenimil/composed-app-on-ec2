output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnets
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "EC2 public IP"
  value       = module.compute.public_ip
}

output "ec2_public_dns" {
  description = "EC2 public DNS"
  value       = module.compute.public_dns
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_registry" {
  description = "ECR registry host"
  value       = split("/", aws_ecr_repository.backend.repository_url)[0]
}

output "github_actions_oidc_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions_ecr.arn
}

output "ec2_app_dir" {
  description = "Application directory expected on EC2"
  value       = var.app_dir
}
