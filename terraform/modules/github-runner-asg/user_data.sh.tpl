#!/bin/bash
# Rendered by Terraform (templatefile) into the launch template's user_data.
# Writes the runner's boot-time configuration - never a credential, just
# where to find one - then starts the systemd-managed ephemeral lifecycle
# baked into the AMI (see packer/files/systemd/github-runner.service).
set -euo pipefail

mkdir -p /etc/github-runner
cat > /etc/github-runner/runner.env <<ENVEOF
GITHUB_URL=${github_url}
RUNNER_LABELS=${runner_labels}
RUNNER_GROUP=${runner_group}
RUNNER_NAME_PREFIX=${runner_name_prefix}
TOKEN_SOURCE=${token_source}
TOKEN_PARAM_NAME=${token_parameter_name}
USE_JIT_CONFIG=${use_jit_config}
AWS_REGION=${aws_region}
ENVEOF
chmod 0644 /etc/github-runner/runner.env

systemctl start github-runner.service
