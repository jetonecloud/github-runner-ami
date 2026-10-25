#
# Build matrix selector
#
# Set via -var-file=packer/x86_64.pkrvars.hcl or packer/arm64.pkrvars.hcl.
# Everything downstream (instance type, source AMI filter, binary arch, checksums)
# is derived from this single value so the two builds stay in lockstep.
variable "arch" {
  type        = string
  description = "Target CPU architecture: \"x86_64\" or \"arm64\"."

  validation {
    condition     = contains(["x86_64", "arm64"], var.arch)
    error_message = "arch must be \"x86_64\" or \"arm64\"."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type used only to *build* the AMI (must match arch family, e.g. t3.medium for x86_64 / t4g.medium for arm64)."
}

#
# AWS / networking
#
variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI in."
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC to launch the temporary build instance in. Empty string uses the account/region default VPC."
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the temporary build instance in. Empty string lets Packer pick a default subnet in the VPC."
  default     = ""
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether the temporary build instance gets a public IP. Set to false if the subnet reaches the internet via NAT/VPC endpoints."
  default     = true
}

variable "security_group_ids" {
  type        = list(string)
  description = "Extra security groups for the temporary build instance. Packer manages its own egress-only SG automatically; add IDs here only if your account requires a baseline SG."
  default     = []
}

#
# AMI metadata
#
variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the resulting AMI name. Final name is \"<prefix>-<arch>-<timestamp>\"."
  default     = "github-runner-ami"
}

variable "ami_version" {
  type        = string
  description = "Human-readable version tag applied to the AMI (e.g. date-based \"2026.10.25\" or a git short SHA). Supplied by CI; defaults to \"dev\" for local builds."
  default     = "dev"
}

variable "ami_regions" {
  type        = list(string)
  description = "Additional regions to copy the built AMI to."
  default     = []
}

variable "ami_users" {
  type        = list(string)
  description = "Additional AWS account IDs to share the built AMI (and its snapshot) with."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto the AMI, snapshot, and build instance."
  default     = {}
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
  description = "KMS key ID/ARN for root volume encryption. Empty string uses the account's default aws/ebs key. The volume is ALWAYS encrypted regardless of this value."
  default     = ""
}

#
# Source AMI selection (Amazon Linux 2023, owned by Amazon)
#
variable "source_ami_owner" {
  type        = string
  description = "Owner account ID for the source Amazon Linux 2023 AMI."
  default     = "137112412989" # Amazon
}

variable "source_ami_name_filter" {
  type        = string
  description = "Name filter for the source Amazon Linux 2023 AMI (globs allowed). %s is replaced with var.arch."
  default     = "al2023-ami-2023.*-kernel-*-%s"
}

#
# GitHub Actions runner (pinned + checksum verified)
#
variable "runner_version" {
  type        = string
  description = "actions/runner release version to install (without leading v)."
  default     = "2.338.1"
}

variable "runner_checksum_x64" {
  type        = string
  description = "SHA-256 of actions-runner-linux-x64-<runner_version>.tar.gz, from the GitHub release notes."
  default     = "08e9ccb3604d2462c24b5e33604dc30810296ca15cc65f23cffd4317eb144c37"
}

variable "runner_checksum_arm64" {
  type        = string
  description = "SHA-256 of actions-runner-linux-arm64-<runner_version>.tar.gz, from the GitHub release notes."
  default     = "475e0c149fd3b611610127b9664ba5bacf5c6928795cc448ab520bb5f324bede"
}

#
# Node.js LTS
#
variable "node_version" {
  type        = string
  description = "Node.js LTS version to install (without leading v)."
  default     = "24.22.1"
}

variable "node_checksum_x64" {
  type        = string
  description = "SHA-256 of node-v<node_version>-linux-x64.tar.xz, from the upstream SHASUMS256.txt."
  default     = "6c172a9ab6718f7b801fb5a7bd486af2ee5e32758086a04b84fcce2aa77095e6"
}

variable "node_checksum_arm64" {
  type        = string
  description = "SHA-256 of node-v<node_version>-linux-arm64.tar.xz, from the upstream SHASUMS256.txt."
  default     = "dbabf7a1cbf947e6059ffad2c27b80041db97dea1e553b62afdee7f13fca336e"
}

#
# Go toolchain
#
variable "go_version" {
  type        = string
  description = "Go version to install (without leading \"go\")."
  default     = "1.27.3"
}

variable "go_checksum_amd64" {
  type        = string
  description = "SHA-256 of go<go_version>.linux-amd64.tar.gz, from https://go.dev/dl/?mode=json."
  default     = "65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40"
}

variable "go_checksum_arm64" {
  type        = string
  description = "SHA-256 of go<go_version>.linux-arm64.tar.gz, from https://go.dev/dl/?mode=json."
  default     = "a06e99309dbcbdca1a8ccd2282c3ee146e55930886e26b4f1193269587165f49"
}

#
# Trivy
#
variable "trivy_version" {
  type        = string
  description = "Trivy version to install (without leading v)."
  default     = "0.76.1"
}

variable "trivy_checksum_x64" {
  type        = string
  description = "SHA-256 of trivy_<trivy_version>_Linux-64bit.tar.gz, from the release checksums.txt."
  default     = "c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0"
}

variable "trivy_checksum_arm64" {
  type        = string
  description = "SHA-256 of trivy_<trivy_version>_Linux-ARM64.tar.gz, from the release checksums.txt."
  default     = "e174dff2a6dba5e3ae41f8d0537a6324405bd08132497340304c6b20e0f16a1f"
}

variable "trivy_fail_severity" {
  type        = string
  description = "Comma-separated severities that fail the in-build Trivy filesystem scan (set to \"\" to disable the gate)."
  default     = "CRITICAL,HIGH"
}

#
# AWS CLI v2 (verified via upstream GPG signature, not a static checksum)
#
variable "awscli_version" {
  type        = string
  description = "AWS CLI v2 version to install."
  default     = "2.38.5"
}

variable "awscli_gpg_fingerprint" {
  type        = string
  description = "Expected primary fingerprint of the AWS CLI Team signing key, per https://docs.aws.amazon.com/cli/latest/userguide/getting-started-gpg-verify.html."
  default     = "FB5DB77FD5C118B80511ADA8A6310ACC4672475C"
}
