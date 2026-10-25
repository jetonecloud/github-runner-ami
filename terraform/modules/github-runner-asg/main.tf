data "aws_region" "current" {}

locals {
  common_tags = merge(
    {
      Name      = var.name
      Project   = "github-runner-ami"
      ManagedBy = "terraform"
    },
    var.tags
  )
}

resource "aws_launch_template" "runner" {
  name_prefix            = "${var.name}-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.runner.name
  }

  # IMDSv2 required - no exceptions. hop_limit=1 also blocks containers on
  # the instance from reaching the metadata service unless explicitly
  # proxied, which is the recommended posture for a Docker-capable runner.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
      delete_on_termination = true
    }
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = var.security_group_ids
    delete_on_termination       = true
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # The runner-cleanup.sh systemd ExecStopPost runs `shutdown -h now` after
  # every job (success, failure, or a registration error). This setting is
  # what turns that OS shutdown into an actual EC2 termination - no
  # ec2:TerminateInstances permission is needed on the instance role.
  instance_initiated_shutdown_behavior = "terminate"

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    github_url           = var.github_url
    runner_labels        = var.runner_labels
    runner_group         = var.runner_group
    runner_name_prefix   = var.runner_name_prefix
    token_source         = var.token_source
    token_parameter_name = var.token_parameter_name
    use_jit_config       = var.use_jit_config
    aws_region           = data.aws_region.current.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Scale-from-zero model: an external webhook/Lambda (or EC2 Fleet calling
# RunInstances/CreateFleet directly with this launch template) is
# responsible for bumping capacity when jobs queue. See
# docs/architecture.md#scale-out-guidance for the trade-offs between
# driving this ASG's desired_capacity vs. launching instances directly.
resource "aws_autoscaling_group" "runner" {
  name_prefix = "${var.name}-"

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.runner.id
    version = "$Latest"
  }

  # Ephemeral instances self-terminate; there's no ELB target to drain.
  health_check_type         = "EC2"
  health_check_grace_period = 120

  termination_policies = ["OldestInstance"]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
