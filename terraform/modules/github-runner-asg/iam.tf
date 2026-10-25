data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name_prefix        = "${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# SSM Session Manager - this is the *only* remote access path; no SSH key,
# no inbound security group rule required.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each   = toset(var.additional_iam_policy_arns)
  role       = aws_iam_role.runner.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "runner_credential_access" {
  dynamic "statement" {
    for_each = length(var.ssm_parameter_arns) > 0 ? [1] : []
    content {
      sid       = "ReadRunnerParameters"
      actions   = ["ssm:GetParameter"]
      resources = var.ssm_parameter_arns
    }
  }

  dynamic "statement" {
    for_each = var.use_jit_config && length(var.ssm_parameter_arns) > 0 ? [1] : []
    content {
      sid       = "DeleteConsumedJitParameters"
      actions   = ["ssm:DeleteParameter"]
      resources = var.ssm_parameter_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.secretsmanager_secret_arns) > 0 ? [1] : []
    content {
      sid       = "ReadRunnerSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.secretsmanager_secret_arns
    }
  }

  dynamic "statement" {
    for_each = var.use_jit_config && length(var.secretsmanager_secret_arns) > 0 ? [1] : []
    content {
      sid       = "DeleteConsumedJitSecrets"
      actions   = ["secretsmanager:DeleteSecret"]
      resources = var.secretsmanager_secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "DecryptCustomerManagedKey"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_policy" "runner_credential_access" {
  name_prefix = "${var.name}-credential-access-"
  description = "Least-privilege read access to the SSM parameter(s)/secret(s) this runner fleet uses to self-register."
  policy      = data.aws_iam_policy_document.runner_credential_access.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "runner_credential_access" {
  role       = aws_iam_role.runner.name
  policy_arn = aws_iam_policy.runner_credential_access.arn
}

resource "aws_iam_instance_profile" "runner" {
  name_prefix = "${var.name}-"
  role        = aws_iam_role.runner.name
  tags        = var.tags
}
