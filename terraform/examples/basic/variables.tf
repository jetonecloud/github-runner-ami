variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for created resources."
  default     = "github-runner"
}

variable "environment" {
  type        = string
  description = "Environment tag value."
  default     = "ci"
}

variable "vpc_id" {
  type        = string
  description = "VPC to deploy into. Subnets are discovered via the \"Tier = private\" tag filter; adjust the aws_subnets data source in main.tf if your subnets are tagged differently."
}

variable "ami_id" {
  type        = string
  description = "AMI ID built by packer/ for the architecture matching var.instance_type."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type (must match the AMI's architecture)."
  default     = "m6i.large"
}

variable "min_size" {
  type    = number
  default = 0
}

variable "max_size" {
  type    = number
  default = 10
}

variable "desired_capacity" {
  type    = number
  default = 0
}

variable "github_url" {
  type        = string
  description = "https://github.com/<org>/<repo> or https://github.com/<org>"
}

variable "runner_labels" {
  type    = string
  default = "self-hosted,linux,ephemeral"
}

variable "token_parameter_name" {
  type        = string
  description = "SSM parameter name holding the registration token or (if use_jit_config) a {instance_id}-templated per-instance JIT config path."
}

variable "token_parameter_arn" {
  type        = string
  description = "ARN (or wildcard ARN, if token_parameter_name contains {instance_id}) of the SSM parameter above, for the least-privilege IAM policy."
}

variable "use_jit_config" {
  type    = bool
  default = false
}
