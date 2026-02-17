
data "aws_ssm_parameter" "amzn2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_key_pair" "ec2" {
  key_name   = var.ec2_key_name
  public_key = trimspace(file(var.ec2_public_key_path))
  tags       = local.common_tags
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  instance_user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_dir                 = var.app_dir
    backend_repository_url  = aws_ecr_repository.backend.repository_url
    frontend_repository_url = aws_ecr_repository.frontend.repository_url
    aws_region              = var.aws_region
  })
}

module "networking" {
  source = "./modules/networking"

  name               = "${local.name_prefix}-vpc"
  cidr               = var.vpc_cidr
  azs                = var.availability_zones
  public_subnets     = var.public_subnet_cidrs
  enable_nat_gateway = false
  single_nat_gateway = false
}

resource "aws_security_group" "ec2_app" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for app EC2 instance"
  vpc_id      = module.networking.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Frontend HTTP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "backend" {
  name                 = var.backend_ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = var.frontend_ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain last 25 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 25
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain last 25 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 25
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}",
        "repo:${var.github_repository}:environment:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_ecr" {
  name               = "${local.name_prefix}-github-actions-ecr"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "github_actions_ecr_push" {
  statement {
    sid    = "AllowEcrAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowPushPullSelectedRepos"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.frontend.arn
    ]
  }
}

resource "aws_iam_policy" "github_actions_ecr_push" {
  name   = "${local.name_prefix}-github-actions-ecr-push"
  policy = data.aws_iam_policy_document.github_actions_ecr_push.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecr_push.arn
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_ecr_pull" {
  name               = "${local.name_prefix}-ec2-ecr-pull"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ec2_ecr_pull" {
  statement {
    sid    = "AllowEcrAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowPullSelectedRepos"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages"
    ]
    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.frontend.arn
    ]
  }

}

resource "aws_iam_policy" "ec2_ecr_pull" {
  name   = "${local.name_prefix}-ec2-ecr-pull"
  policy = data.aws_iam_policy_document.ec2_ecr_pull.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_pull" {
  role       = aws_iam_role.ec2_ecr_pull.name
  policy_arn = aws_iam_policy.ec2_ecr_pull.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_ecr_pull.name
  tags = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  name = "${local.name_prefix}-ec2"

  ami                    = var.ec2_ami_id != "" ? var.ec2_ami_id : data.aws_ssm_parameter.amzn2_ami.value
  instance_type          = var.instance_type
  subnet_id              = module.networking.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_app.id]

  key_name             = aws_key_pair.ec2.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  user_data            = local.instance_user_data
}
