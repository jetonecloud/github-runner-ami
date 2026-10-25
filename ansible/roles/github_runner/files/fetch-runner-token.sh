#!/usr/bin/env bash
# Fetch the runner's registration credential from SSM Parameter Store or
# Secrets Manager. Prints the credential to stdout and nothing else - the
# caller (runner-register.sh) captures it directly into memory/a 0600 file,
# never into shell history or a log line.
set -euo pipefail

: "${TOKEN_SOURCE:?missing}" "${TOKEN_PARAM_NAME:?missing}"

region_args=()
if [ -n "${AWS_REGION:-}" ]; then
  region_args=(--region "${AWS_REGION}")
fi

case "${TOKEN_SOURCE}" in
  ssm)
    aws ssm get-parameter \
      --name "${TOKEN_PARAM_NAME}" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text \
      "${region_args[@]}"
    ;;
  secretsmanager)
    aws secretsmanager get-secret-value \
      --secret-id "${TOKEN_PARAM_NAME}" \
      --query 'SecretString' \
      --output text \
      "${region_args[@]}"
    ;;
  *)
    echo "fetch-runner-token: unsupported TOKEN_SOURCE '${TOKEN_SOURCE}' (expected ssm|secretsmanager)" >&2
    exit 1
    ;;
esac
