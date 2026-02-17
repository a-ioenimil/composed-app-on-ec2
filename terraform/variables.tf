variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "composed-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for public subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami_id" {
  description = "Optional override for EC2 AMI ID"
  type        = string
  default     = ""
}

variable "ec2_key_name" {
  description = "EC2 key pair name to create and attach for SSH"
  type        = string
}

variable "ec2_public_key_path" {
  description = "Absolute path to local SSH public key (.pub) file"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to EC2"
  type        = string
  default     = "0.0.0.0/0"
}

variable "backend_ecr_repo_name" {
  description = "ECR repository name for backend image"
  type        = string
  default     = "todo-backend"
}

variable "frontend_ecr_repo_name" {
  description = "ECR repository name for frontend image"
  type        = string
  default     = "todo-frontend"
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume OIDC role"
  type        = string
  default     = "main"
}

variable "app_dir" {
  description = "App directory on EC2 where docker-compose.yml is located"
  type        = string
  default     = "/opt/composed-app-on-ec2"
}

variable "secrets_manager_secret_name" {
  description = "Optional Secrets Manager secret name for runtime app env vars"
  type        = string
  default     = ""
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "todo_db"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "todo_user"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
