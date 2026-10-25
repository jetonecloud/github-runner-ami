# Minimal runnable example wiring up terraform/modules/github-runner-asg.
#
# This deploys a scale-to-zero ASG (min=max=desired=0 by default) behind a
# security group with no inbound rules at all - access is via SSM Session
# Manager only. A webhook/Lambda or EC2 Fleet caller is expected to bump
# capacity on demand; see ../../../docs/architecture.md#scale-out-guidance.
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "private"
  }
}

# No inbound rules anywhere - SSM Session Manager needs none. Egress is
# limited to HTTPS, which is sufficient for the SSM/EC2/GitHub endpoints the
# runner needs to reach (use VPC endpoints instead of 0.0.0.0/0 in
# production - see docs/security.md).
resource "aws_security_group" "runner" {
  name_prefix = "github-runner-"
  description = "Ephemeral GitHub Actions runners - no inbound access"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to AWS APIs, GitHub, and package/registry mirrors"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "github-runner"
  }
}

module "github_runner" {
  source = "../../modules/github-runner-asg"

  name          = var.name
  ami_id        = var.ami_id
  instance_type = var.instance_type

  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.runner.id]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  github_url           = var.github_url
  runner_labels        = var.runner_labels
  token_source         = "ssm"
  token_parameter_name = var.token_parameter_name
  use_jit_config       = var.use_jit_config
  ssm_parameter_arns   = [var.token_parameter_arn]

  tags = {
    Environment = var.environment
  }
}
