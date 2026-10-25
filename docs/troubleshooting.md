# Troubleshooting

There's no SSH into these instances by design - use SSM Session Manager for everything
below:

```bash
aws ssm start-session --target <instance-id>
```

## Instance boots but the runner never registers

Check the systemd unit and its logs first:

```bash
sudo systemctl status github-runner.service
sudo journalctl -u github-runner -b --no-pager
```

Common causes:

- **`/etc/github-runner/runner.env` is missing or malformed.** The unit has
  `ConditionPathExists=/etc/github-runner/runner.env`; if the file isn't there,
  `systemctl status` shows the unit as inactive/skipped. This file is written by
  Terraform's `user_data` (`terraform/modules/github-runner-asg/user_data.sh.tpl`) - if
  you launch an instance from the AMI without going through that (or an equivalent)
  user_data, you need to write it yourself.
- **IAM can't read the SSM parameter/secret.** `runner-register.sh` calls
  `fetch-runner-token.sh`, which calls `aws ssm get-parameter` /
  `aws secretsmanager get-secret-value`. An `AccessDenied` here almost always means
  `ssm_parameter_arns`/`secretsmanager_secret_arns` passed to the Terraform module
  doesn't match the actual parameter ARN (check for a region/account mismatch, or a
  wildcard that doesn't cover the exact name).
- **The parameter is empty or expired.** Registration tokens expire after about an
  hour; if your webhook/Lambda isn't refreshing it, `config.sh` fails with an
  authentication error visible in the journal.
- **`{instance_id}` substitution mismatch (JIT mode).** If `use_jit_config = true`,
  `TOKEN_PARAM_NAME` must contain the literal substring `{instance_id}`, and whatever
  wrote the JIT config must have used the *same* instance ID in the parameter path.

## Instance never terminates after a job

```bash
sudo journalctl -u github-runner -b --no-pager | tail -50
```

- Look for the `runner-cleanup.sh` log lines (tagged `github-runner-cleanup` via
  `logger`). If cleanup never ran, check whether `ExecStart` is still running (a hung
  job) - `ExecStopPost` only fires once the main process exits.
- If cleanup ran but the instance is still up, check
  `instance_initiated_shutdown_behavior` on the launch template - if it's `stop`
  (the AWS default) instead of `terminate`, `shutdown -h now` just stops the instance
  instead of terminating it. The module sets this to `terminate`; if you're not using
  the module, set it explicitly.

## Packer build fails during the Trivy scan step

`packer/scripts/95-trivy-scan.sh` fails the build on HIGH/CRITICAL findings. The Packer
log prints a human-readable table; the full JSON report is at
`/tmp/trivy-fs-report.json` **inside the build instance**, which Packer normally
terminates on failure - re-run with `PACKER_LOG=1` and `-on-error=ask` to pause before
teardown and inspect it over the build instance's temporary SSH session, or add a
`-var trivy_fail_severity=` (empty string) locally to see the full report without
failing, then decide whether to bump the affected package/tool's pinned version or
accept the finding.

## Packer can't reach the build instance / downloads fail

The build instance needs outbound internet access (or VPC endpoints + appropriate DNS)
to reach:

- The Amazon Linux 2023 package repos (dnf)
- `github.com` / `objects.githubusercontent.com` (runner, Trivy, buildx release assets)
- `nodejs.org`, `go.dev` (Node.js, Go tarballs)
- `awscli.amazonaws.com`, `keys.openpgp.org` / `keyserver.ubuntu.com` (AWS CLI + GPG key)

If `var.subnet_id` points at a private subnet, make sure it has a NAT gateway (or the
necessary VPC endpoints) before building - this is a build-time requirement, separate
from the runtime network posture described in `docs/security.md`.

## GitHub Actions build pipeline fails on `sts:AssumeRoleWithWebIdentity`

This is an OIDC trust policy mismatch, not a Packer/Terraform problem. Check that the
IAM role in `vars.AWS_BUILD_ROLE_ARN` trusts GitHub's OIDC provider
(`token.actions.githubusercontent.com`) with a condition scoped to this repository,
e.g.:

```json
"Condition": {
  "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
  "StringLike": { "token.actions.githubusercontent.com:sub": "repo:jetonecloud/github-runner-ami:*" }
}
```

A `sub` claim that's too narrow (e.g. pinned to a specific branch) will reject runs
from other branches/PRs/environments - widen it deliberately, don't drop the condition
entirely.

## Docker permission denied inside a job

The `runner` user is added to the `docker` group at bake time
(`packer/scripts/20-install-docker.sh`); the systemd unit also sets
`SupplementaryGroups=docker` as a second guarantee. If you're launching the runner
outside systemd (e.g. for local debugging), make sure whatever starts `run.sh` runs as
a user in the `docker` group - group membership changes don't apply to processes
started before the membership was added.

## Smoke test times out

`test/smoke-test.sh` has an overall `TIMEOUT_SECONDS` (default 900s/15 min) covering
instance boot, registration, job execution, and self-termination. If it times out:

1. Confirm `test/sample-workflow.yml` is actually committed to
   `TEST_REPO/.github/workflows/sample-workflow.yml` on the default branch - GitHub
   rejects dispatch requests for workflows that don't exist there yet.
2. Check that `GITHUB_TOKEN` can mint registration tokens on `TEST_REPO` (needs
   `administration:write` for a fine-grained PAT, or `repo` scope for a classic PAT).
3. SSM into the instance (it won't have terminated yet if the job is stuck) and check
   `journalctl -u github-runner` as above.
