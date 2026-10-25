locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
  ami_name  = "${var.ami_name_prefix}-${var.arch}-${local.timestamp}"

  common_tags = merge(
    {
      Name          = local.ami_name
      Project       = "github-runner-ami"
      Architecture  = var.arch
      RunnerVersion = var.runner_version
      AmiVersion    = var.ami_version
      ManagedBy     = "packer"
    },
    var.tags
  )
}

source "amazon-ebs" "github_runner" {
  region = var.aws_region

  ami_name        = local.ami_name
  ami_description = "Ephemeral self-hosted GitHub Actions runner (${var.arch}) - Amazon Linux 2023, runner v${var.runner_version}"

  instance_type = var.instance_type

  source_ami_filter {
    owners      = [var.source_ami_owner]
    most_recent = true
    filters = {
      name                = format(var.source_ami_name_filter, var.arch)
      architecture        = var.arch
      virtualization-type = "hvm"
      root-device-type    = "ebs"
      state               = "available"
    }
  }

  ssh_username  = "ec2-user"
  ssh_interface = "public_ip"

  # The build instance itself talks to IMDSv2 only; this also becomes the
  # default on the resulting AMI's launch template metadata, but is always
  # overridden explicitly by Terraform at launch time too (belt and suspenders).
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  vpc_id                      = var.vpc_id != "" ? var.vpc_id : null
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = var.associate_public_ip_address
  security_group_ids          = length(var.security_group_ids) > 0 ? var.security_group_ids : null

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
  }

  ami_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
  }

  encrypt_boot = true
  kms_key_id   = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null

  ami_regions = var.ami_regions
  ami_users   = var.ami_users

  run_tags        = local.common_tags
  run_volume_tags = local.common_tags
  tags            = local.common_tags
  snapshot_tags   = local.common_tags

  # Image never ships credentials; the build role only needs ec2:Describe*,
  # RunInstances/TerminateInstances on the ephemeral build instance, and
  # CreateImage/CopyImage permissions (see docs/security.md).
}
