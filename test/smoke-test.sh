#!/usr/bin/env bash
# End-to-end smoke test: boots a real EC2 instance from a built AMI,
# registers it as an ephemeral runner against a test repo, dispatches
# test/sample-workflow.yml, waits for it to complete, and confirms the
# instance terminates itself afterward.
#
# Prerequisites:
#   - test/sample-workflow.yml is committed to TEST_REPO's default branch
#     (GitHub only allows dispatching workflows that already exist there).
#   - An IAM instance profile that grants ssm:GetParameter/DeleteParameter
#     on TOKEN_PARAM_NAME and AmazonSSMManagedInstanceCore (e.g. the
#     iam_instance_profile_name output of terraform/modules/github-runner-asg).
#   - A GITHUB_TOKEN with permission to mint registration tokens and
#     dispatch/read workflow runs on TEST_REPO (repo scope / Actions: write).
#
# Required environment variables:
#   AMI_ID                  AMI built by packer/ to boot
#   SUBNET_ID               Subnet to launch into (must reach AWS APIs/GitHub)
#   SECURITY_GROUP_ID       Security group (no inbound rules needed)
#   INSTANCE_PROFILE_NAME   IAM instance profile (see prerequisites)
#   TEST_REPO               owner/repo to register the runner against
#   GITHUB_TOKEN            token used to mint the registration token + call the API
#
# Optional:
#   AWS_REGION              default us-east-1
#   INSTANCE_TYPE           default t3.medium
#   RUNNER_LABELS           default self-hosted,linux,ephemeral,smoke-test
#   TOKEN_PARAM_NAME        default /github-runner/smoke-test/registration-token
#   WORKFLOW_FILE           default sample-workflow.yml (filename in TEST_REPO's .github/workflows/)
#   TIMEOUT_SECONDS         overall timeout, default 900 (15 min)
#   KEEP_INSTANCE           if "true", don't terminate on failure (debugging)
set -euo pipefail

: "${AMI_ID:?set AMI_ID}"
: "${SUBNET_ID:?set SUBNET_ID}"
: "${SECURITY_GROUP_ID:?set SECURITY_GROUP_ID}"
: "${INSTANCE_PROFILE_NAME:?set INSTANCE_PROFILE_NAME}"
: "${TEST_REPO:?set TEST_REPO (owner/repo)}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN}"

AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,ephemeral,smoke-test}"
TOKEN_PARAM_NAME="${TOKEN_PARAM_NAME:-/github-runner/smoke-test/registration-token}"
WORKFLOW_FILE="${WORKFLOW_FILE:-sample-workflow.yml}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
KEEP_INSTANCE="${KEEP_INSTANCE:-false}"

MARKER="smoke-$(date +%s)-$$"
INSTANCE_ID=""
START_TIME="$(date +%s)"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

elapsed() { echo $(( $(date +%s) - START_TIME )); }
remaining_or_die() {
  local left=$(( TIMEOUT_SECONDS - $(elapsed) ))
  [ "${left}" -gt 0 ] || die "timed out after ${TIMEOUT_SECONDS}s waiting on: $1"
}

cleanup() {
  local status=$?
  if [ -n "${INSTANCE_ID}" ] && [ "${KEEP_INSTANCE}" != "true" ]; then
    log "cleanup: terminating instance ${INSTANCE_ID}"
    aws ec2 terminate-instances --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}" >/dev/null 2>&1 || true
  fi
  aws ssm delete-parameter --region "${AWS_REGION}" --name "${TOKEN_PARAM_NAME}" >/dev/null 2>&1 || true
  exit "${status}"
}
trap cleanup EXIT

command -v aws >/dev/null || die "aws CLI is required"
command -v gh >/dev/null || die "gh CLI is required"
command -v jq >/dev/null || die "jq is required"

log "1/6 minting a registration token for ${TEST_REPO} and storing it in SSM"
reg_token="$(gh api --method POST "repos/${TEST_REPO}/actions/runners/registration-token" -q .token)"
aws ssm put-parameter \
  --region "${AWS_REGION}" \
  --name "${TOKEN_PARAM_NAME}" \
  --type SecureString \
  --overwrite \
  --value "${reg_token}" >/dev/null
unset reg_token

log "2/6 launching ${INSTANCE_TYPE} from ${AMI_ID} in ${SUBNET_ID}"
user_data="$(cat <<EOF
#!/bin/bash
set -euo pipefail
mkdir -p /etc/github-runner
cat > /etc/github-runner/runner.env <<ENVEOF
GITHUB_URL=https://github.com/${TEST_REPO}
RUNNER_LABELS=${RUNNER_LABELS}
RUNNER_GROUP=default
RUNNER_NAME_PREFIX=smoke
TOKEN_SOURCE=ssm
TOKEN_PARAM_NAME=${TOKEN_PARAM_NAME}
USE_JIT_CONFIG=false
AWS_REGION=${AWS_REGION}
ENVEOF
chmod 0644 /etc/github-runner/runner.env
systemctl start github-runner.service
EOF
)"

INSTANCE_ID="$(aws ec2 run-instances \
  --region "${AWS_REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type "${INSTANCE_TYPE}" \
  --subnet-id "${SUBNET_ID}" \
  --security-group-ids "${SECURITY_GROUP_ID}" \
  --iam-instance-profile "Name=${INSTANCE_PROFILE_NAME}" \
  --instance-initiated-shutdown-behavior terminate \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=1" \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={Encrypted=true,DeleteOnTermination=true}' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=github-runner-smoke-test},{Key=Marker,Value=${MARKER}}]" \
  --user-data "${user_data}" \
  --query 'Instances[0].InstanceId' \
  --output text)"
log "launched ${INSTANCE_ID}"

log "3/6 waiting for ${INSTANCE_ID} to reach running"
aws ec2 wait instance-running --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}"

log "4/6 dispatching ${WORKFLOW_FILE} on ${TEST_REPO} (marker=${MARKER})"
gh api --method POST "repos/${TEST_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches" \
  -f "ref=$(gh api "repos/${TEST_REPO}" -q .default_branch)" \
  -f "inputs[run_marker]=${MARKER}" >/dev/null

log "5/6 waiting for a run named smoke-test: ${MARKER} to appear and finish"
run_id=""
while [ -z "${run_id}" ]; do
  remaining_or_die "workflow run to appear"
  run_id="$(gh api "repos/${TEST_REPO}/actions/runs?event=workflow_dispatch&per_page=20" \
    -q ".workflow_runs[] | select(.name | test(\"${MARKER}\")) | .id" | head -n1 || true)"
  [ -n "${run_id}" ] || sleep 5
done
log "found run ${run_id}"

status=""
conclusion=""
while [ "${status}" != "completed" ]; do
  remaining_or_die "workflow run to complete"
  sleep 10
  read -r status conclusion < <(gh api "repos/${TEST_REPO}/actions/runs/${run_id}" -q '.status + " " + (.conclusion // "null")')
done

[ "${conclusion}" = "success" ] || die "workflow run ${run_id} concluded '${conclusion}', expected 'success' (see https://github.com/${TEST_REPO}/actions/runs/${run_id})"
log "run ${run_id} succeeded"

log "6/6 waiting for ${INSTANCE_ID} to self-terminate (ephemeral lifecycle)"
while true; do
  remaining_or_die "instance to terminate"
  state="$(aws ec2 describe-instances --region "${AWS_REGION}" --instance-ids "${INSTANCE_ID}" \
    --query 'Reservations[0].Instances[0].State.Name' --output text)"
  case "${state}" in
    shutting-down|terminated)
      log "instance reached '${state}'"
      INSTANCE_ID="" # already terminating itself; nothing for cleanup() to do
      break
      ;;
    *)
      sleep 10
      ;;
  esac
done

log "SMOKE TEST PASSED in $(elapsed)s"
