#!/usr/bin/env bash
# ExecStopPost for github-runner.service, run as root ("+" prefix in the
# unit) regardless of how/whether the runner started or finished. Wipes the
# workspace and Docker state, then shuts the OS down. The launch template
# sets InstanceInitiatedShutdownBehavior=terminate, so this is what actually
# terminates the EC2 instance - no ec2:TerminateInstances IAM permission
# needed on the instance role.
set -uo pipefail

RUNNER_DIR=/opt/actions-runner
WORK_DIR="${RUNNER_DIR}/_work"

logger -t github-runner-cleanup "job finished; wiping workspace and Docker state before terminating"

# Belt-and-suspenders: --ephemeral already deregisters the runner after a
# completed job, but clear any credential files left behind on any exit path.
rm -f "${RUNNER_DIR}"/.credentials "${RUNNER_DIR}"/.credentials_rsaparams "${RUNNER_DIR}"/.runner "${RUNNER_DIR}"/.jitconfig

rm -rf "${WORK_DIR}"
install -d -m 0750 -o runner -g runner "${WORK_DIR}"

if systemctl is-active --quiet docker; then
  # shellcheck disable=SC2046
  docker rm -f $(docker ps -aq) >/dev/null 2>&1
  docker system prune -af --volumes >/dev/null 2>&1
fi

logger -t github-runner-cleanup "cleanup complete; terminating instance"
shutdown -h now
