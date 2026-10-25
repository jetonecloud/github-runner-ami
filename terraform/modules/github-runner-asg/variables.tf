variable "name" {
  type        = string
  description = "Name prefix for all resources created by this module."
  default     = "github-runner"
}

variable "ami_id" {
  type        = string
  description = "AMI ID produced by packer/ (github-runner-ami), matching the instance_type's architecture."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type. Must match the AMI's architecture (e.g. m6i.large for x86_64, m6g.large for arm64)."
  default     = "m6i.large"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets the Auto Scaling Group launches instances into. Private subnets with a NAT gateway or VPC endpoints for SSM/EC2/S3 are strongly recommended (see docs/security.md)."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups attached to runner instances. Must not allow inbound SSH; SSM Session Manager needs no inbound rule at all, only outbound HTTPS (or VPC endpoints)."
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether runner instances get a public IP. Leave false when subnets reach the internet (or AWS APIs) via NAT/VPC endpoints."
  default     = false
}

#
# Capacity
#
variable "min_size" {
  type        = number
  description = "Auto Scaling Group minimum size. Defaults to 0 (scale-from-zero model driven by an external webhook/Lambda or EC2 Fleet - see docs/architecture.md)."
  default     = 0
}

variable "max_size" {
  type        = number
  description = "Auto Scaling Group maximum size."
  default     = 10
}

variable "desired_capacity" {
  type        = number
  description = "Auto Scaling Group desired capacity. Leave at 0 to scale entirely from an external trigger; set >0 for a fixed-size always-on warm pool."
  default     = 0
}

#
# Runner registration (consumed by /etc/github-runner/runner.env, written by
# user_data.sh.tpl at boot - never baked into the AMI)
#
variable "github_url" {
  type        = string
  description = "Repository (https://github.com/<org>/<repo>) or organization (https://github.com/<org>) URL the runner registers against."
}

variable "runner_labels" {
  type        = string
  description = "Comma-separated labels applied to the runner."
  default     = "self-hosted,linux,ephemeral"
}

variable "runner_group" {
  type        = string
  description = "Runner group to register into."
  default     = "default"
}

variable "runner_name_prefix" {
  type        = string
  description = "Prefix for the runner name; the instance ID is appended at boot."
  default     = "gha"
}

variable "token_source" {
  type        = string
  description = "Where the runner credential is read from at boot: \"ssm\" (Parameter Store) or \"secretsmanager\"."
  default     = "ssm"

  validation {
    condition     = contains(["ssm", "secretsmanager"], var.token_source)
    error_message = "token_source must be \"ssm\" or \"secretsmanager\"."
  }
}

variable "token_parameter_name" {
  type        = string
  description = "SSM parameter name or Secrets Manager secret ID/ARN holding the credential. May contain the literal substring \"{instance_id}\" for a per-instance one-time JIT config path (e.g. /github-runner/jit/{instance_id})."
}

variable "use_jit_config" {
  type        = bool
  description = "If true, token_parameter_name holds a ready-made single-use JIT config (from the GitHub \"generate-jitconfig\" API) instead of a registration token. The parameter is deleted after the instance reads it."
  default     = false
}

#
# IAM (least privilege: SSM Session Manager + scoped read access to exactly
# the credential parameter/secret this fleet uses)
#
variable "ssm_parameter_arns" {
  type        = list(string)
  description = "SSM parameter ARNs the instance role may GetParameter/DeleteParameter on. Use a wildcard ARN (e.g. .../github-runner/jit/*) if token_parameter_name contains {instance_id}."
  default     = []
}

variable "secretsmanager_secret_arns" {
  type        = list(string)
  description = "Secrets Manager secret ARNs the instance role may GetSecretValue/DeleteSecret on."
  default     = []
}

variable "kms_key_arns" {
  type        = list(string)
  description = "KMS key ARNs to grant kms:Decrypt on. Only needed if the SSM parameter/secret is encrypted with a customer-managed key rather than the AWS-managed default (aws/ssm, aws/secretsmanager)."
  default     = []
}

variable "additional_iam_policy_arns" {
  type        = list(string)
  description = "Extra managed policy ARNs to attach to the instance role (e.g. for CloudWatch Logs)."
  default     = []
}

#
# Storage
#
variable "root_volume_size_gb" {
  type        = number
  description = "Root EBS volume size in GiB."
  default     = 30
}

variable "ebs_kms_key_id" {
  type        = string
  description = "KMS key ID/ARN for root volume encryption. Empty string uses the account default aws/ebs key. The volume is ALWAYS encrypted regardless of this value."
  default     = ""
}

variable "enable_detailed_monitoring" {
  type        = bool
  description = "Enable EC2 detailed (1-minute) monitoring."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the launch template, ASG, instances, and IAM resources."
  default     = {}
}
