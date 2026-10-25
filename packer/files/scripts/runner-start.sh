#!/usr/bin/env bash
# ExecStart for github-runner.service. Picks the right invocation depending
# on whether runner-register.sh wrote a one-shot JIT config or ran
# config.sh with a registration token. Either way, run.sh exits after
# exactly one job because the runner is ephemeral.
set -euo pipefail

cd /opt/actions-runner

if [ -f .jitconfig ]; then
  jit_config="$(cat .jitconfig)"
  rm -f .jitconfig
  exec ./run.sh --jitconfig "${jit_config}"
fi

exec ./run.sh
