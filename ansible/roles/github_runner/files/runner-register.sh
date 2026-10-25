#!/usr/bin/env bash
# Runs as ExecStartPre for github-runner.service (as the unprivileged
# `runner` user). Resolves this instance's credential from SSM/Secrets
# Manager and either:
#   - writes a one-shot JIT config (USE_JIT_CONFIG=true), consumed by
#     runner-start.sh via `run.sh --jitconfig`, or
#   - runs `config.sh` with a short-lived registration token
#     (USE_JIT_CONFIG=false, the default).
#
# No credential is ever baked into the AMI; everything here is fetched at
# boot and scoped to this one instance/job.
set -euo pipefail

: "${GITHUB_URL:?missing}" "${TOKEN_SOURCE:?missing}" "${TOKEN_PARAM_NAME:?missing}"

RUNNER_DIR=/opt/actions-runner
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,ephemeral}"
RUNNER_GROUP="${RUNNER_GROUP:-default}"
RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX:-gha}"
USE_JIT_CONFIG="${USE_JIT_CONFIG:-false}"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${RUNNER_DIR}"

if [ -f .runner ] || [ -f .jitconfig ]; then
  echo "runner-register: instance already configured, skipping" >&2
  exit 0
fi

imds_token="$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")"
instance_id="$(curl -fsS -H "X-aws-ec2-metadata-token: ${imds_token}" \
  "http://169.254.169.254/latest/meta-data/instance-id")"

# Allows a per-instance credential path, e.g. a launch lifecycle hook that
# writes a one-time JIT config to /github-runner/jit/{instance_id}.
param_name="${TOKEN_PARAM_NAME//\{instance_id\}/${instance_id}}"
runner_name="${RUNNER_NAME_PREFIX}-${instance_id}"

credential="$(TOKEN_PARAM_NAME="${param_name}" "${BIN_DIR}/fetch-runner-token.sh")"

if [ -z "${credential}" ]; then
  echo "runner-register: empty credential from ${TOKEN_SOURCE}:${param_name}" >&2
  exit 1
fi

if [ "${USE_JIT_CONFIG}" = "true" ]; then
  umask 077
  printf '%s' "${credential}" > .jitconfig

  region_args=()
  if [ -n "${AWS_REGION:-}" ]; then
    region_args=(--region "${AWS_REGION}")
  fi

  # JIT configs are single-use; delete the parameter so it can't be reused
  # or read again if this instance is ever inspected.
  if [ "${TOKEN_SOURCE}" = "ssm" ]; then
    aws ssm delete-parameter --name "${param_name}" "${region_args[@]}" || true
  else
    aws secretsmanager delete-secret --secret-id "${param_name}" --force-delete-without-recovery "${region_args[@]}" || true
  fi
  exit 0
fi

./config.sh --unattended \
  --url "${GITHUB_URL}" \
  --token "${credential}" \
  --name "${runner_name}" \
  --labels "${RUNNER_LABELS}" \
  --runnergroup "${RUNNER_GROUP}" \
  --work _work \
  --ephemeral \
  --disableupdate
unset credential
