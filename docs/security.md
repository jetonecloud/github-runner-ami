# Security notes

## Threat model

A GitHub Actions runner executes arbitrary, workflow-defined code (including
third-party actions) with whatever permissions the runner's environment grants. The
main risks this design addresses:

1. **A compromised/malicious job persists or pivots.** Mitigated by the ephemeral,
   single-job lifecycle: every instance is destroyed after one job, so there's no
   persistent filesystem, credential, or network session for a compromised job to
   leave behind for the *next* job to inherit.
2. **A compromised job steals the runner's AWS credentials to pivot in the account.**
   Mitigated by least-privilege IAM (see below) - the instance role can read exactly
   the SSM parameter/secret it needs and nothing else, and cannot terminate instances,
   modify the ASG, or reach other AWS resources.
3. **A compromised job uses the EC2 metadata service to steal credentials via SSRF**
   (the classic IMDSv1 attack pattern). Mitigated by requiring IMDSv2
   (`http_tokens = "required"`) with `http_put_response_hop_limit = 1`, which also means
   a container running on the instance can't reach IMDS through the host network stack
   unless it's explicitly proxied.
4. **An attacker reaches the runner over the network.** Mitigated by having no SSH
   server at all (`sshd.service` is disabled in the AMI) and no inbound security group
   rule anywhere in the Terraform module; the only remote access path is SSM Session
   Manager, which is authenticated and authorized through IAM, not a listening port.
5. **A vulnerable package ships in the AMI.** Mitigated by an in-build Trivy filesystem
   scan (`packer/scripts/95-trivy-scan.sh`) that fails the build on HIGH/CRITICAL
   findings, plus a weekly rebuild (`weekly-rebuild.yml`) that picks up OS package
   patches even when nobody touches this repo that week.
6. **Supply-chain tampering of a downloaded tool.** Every third-party binary (the
   runner, Node.js, Go, Trivy, the buildx plugin) is pinned to an exact version and
   verified against a SHA-256 published by the upstream project before it's installed;
   the AWS CLI v2 installer is verified against the AWS CLI Team's GPG signature
   (AWS does not publish a static checksum for that artifact). See
   `packer/variables.pkr.hcl` for the pinned values and their sources.

## Known accepted risk: Docker access

The runner user is in the `docker` group so jobs can build/run containers. Docker
socket access is effectively root-equivalent on the instance. This is accepted here
because:

- The instance is ephemeral and destroyed after one job - there's no "next job" on the
  same host for a container-escape to pivot into.
- The instance role is scoped tightly enough (see below) that even full host compromise
  doesn't hand an attacker meaningful AWS permissions.

If your threat model requires stronger isolation between the job and the host (e.g.
multi-tenant workflows you don't fully trust), consider rootless Docker, a gVisor/Kata
runtime, or Sysbox on top of this AMI - not implemented here, since it changes the
Docker-in-Docker ergonomics workflows expect.

## IMDSv2

Enforced in two independent places, so it holds regardless of how the AMI is launched:

- `packer/sources.pkr.hcl`: the Packer build instance itself requires IMDSv2.
- `terraform/modules/github-runner-asg/main.tf`: the launch template's
  `metadata_options` block requires IMDSv2 with `http_put_response_hop_limit = 1`.

## SSM Session Manager, not SSH

- `packer/scripts/90-security-hardening.sh` disables (not just stops) `sshd.service`
  and additionally hardens `sshd_config` (`PermitRootLogin no`,
  `PasswordAuthentication no`, forwarding disabled) as defense in depth, in case an
  operator ever re-enables it manually.
- `packer/scripts/99-cleanup.sh` removes the static SSH host keys before the AMI is
  sealed, so there's nothing to reuse even if sshd were re-enabled.
- The instance role includes `AmazonSSMManagedInstanceCore`, and
  `amazon-ssm-agent` is enabled. Access an instance with
  `aws ssm start-session --target <instance-id>` - no key pair, no security group rule.
- Terraform's example security group has **zero inbound rules**.

## Least-privilege IAM

The module's instance role (`terraform/modules/github-runner-asg/iam.tf`) attaches:

- `AmazonSSMManagedInstanceCore` (AWS managed policy) - Session Manager only; it does
  not grant any EC2, S3, or other service access beyond what Session Manager itself
  needs.
- A scoped inline-equivalent policy granting `ssm:GetParameter` /
  `secretsmanager:GetSecretValue` **only on the ARNs you pass into
  `ssm_parameter_arns` / `secretsmanager_secret_arns`** - not `*`. `ssm:DeleteParameter`
  / `secretsmanager:DeleteSecret` are granted on those same ARNs only when
  `use_jit_config = true` (needed to consume a one-time JIT config exactly once).
- Optionally, `kms:Decrypt` on specific key ARNs, only if you encrypt the parameter/
  secret with a customer-managed KMS key instead of the AWS-managed default.

Deliberately **not** granted: `ec2:TerminateInstances` (the instance terminates itself
via `shutdown -h now` + `instance_initiated_shutdown_behavior = "terminate"`, so no EC2
write permission is needed at all), broad `ssm:*`/`secretsmanager:*`, and any
cross-account or cross-service access. Add `additional_iam_policy_arns` only for
genuinely needed extras (e.g. CloudWatch Logs).

## Encryption

- The AMI's root volume is always encrypted (`encrypt_boot = true` in
  `packer/sources.pkr.hcl`), regardless of whether you supply a customer KMS key.
- The launch template's root volume is always encrypted
  (`block_device_mappings.ebs.encrypted = true`).
- SSM SecureString parameters and Secrets Manager secrets are encrypted at rest by
  default (AWS-managed key, or your own CMK via `kms_key_arns`).

## No secrets in the image

Nothing under `packer/` or `ansible/` ever embeds a GitHub token, registration
credential, or AWS credential. `/etc/github-runner/runner.env` - which points at
*where* to find the credential, not the credential itself - is written by Terraform's
`user_data` at boot, not baked into the AMI. The credential itself is fetched directly
from SSM/Secrets Manager into memory by `runner-register.sh` at boot and is never
written to a log.

## Residual risks / not implemented here

Being transparent about what this repo does *not* do, so you can decide whether to add
it:

- **Network egress is not restricted** by this repo's example security group beyond
  "HTTPS out" - a compromised job can still reach any HTTPS endpoint on the internet. If
  your threat model requires an egress allowlist, add it at the security group/VPC
  firewall layer, ideally paired with VPC endpoints for AWS APIs so AWS traffic never
  needs to leave the VPC.
- **No container sandboxing** beyond standard Docker (see "Known accepted risk" above).
- **The webhook/Lambda that mints credentials and drives scale-out is not included** -
  see [docs/architecture.md](architecture.md#scale-out-guidance). Its own security
  (webhook signature verification, least-privilege Lambda role) is out of this repo's
  scope but matters just as much as everything above.
