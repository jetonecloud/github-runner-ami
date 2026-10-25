# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses date-based AMI version tags (`vYYYY.MM.DD-<short_sha>`) produced
by the weekly rebuild and on-demand build pipelines, alongside semantic versioning for
the Terraform module and tooling itself.

## [Unreleased]

### Added
- Initial public release of the `github-runner-ami` project.
- Packer HCL2 templates to build an Amazon Linux 2023 AMI (x86_64 and arm64) with:
  GitHub Actions runner (pinned + checksum-verified), Docker + buildx, git, AWS CLI v2,
  Node.js LTS, Python 3, Go, jq, unzip, and Trivy.
- Shell-based provisioning scripts, with an equivalent Ansible playbook as an
  alternative provisioning path.
- systemd-managed ephemeral runner lifecycle: fetch a JIT/registration credential from
  SSM Parameter Store or Secrets Manager at boot, register with `--ephemeral`, run
  exactly one job, wipe the workspace and Docker state, then terminate the instance.
- Security hardening: IMDSv2 required, SSM Session Manager only (no SSH), encrypted EBS
  volumes, least-privilege IAM instance profile example, no secrets baked into the AMI.
- Terraform module (`terraform/modules/github-runner-asg`) for a launch template + Auto
  Scaling Group, plus a runnable example and scale-out guidance (webhook/Lambda,
  EC2 Fleet, or actions-runner-controller as a Kubernetes-based alternative).
- Smoke test script that boots the AMI, registers against a test repository, runs a
  sample workflow, and verifies self-termination.
- GitHub Actions CI/CD: validation (fmt/lint), OIDC-authenticated AMI build and publish
  per architecture, in-build Trivy vulnerability gate, smoke test, and a weekly
  scheduled rebuild for OS and runner updates.
- Documentation: README quick start and architecture diagram, cost comparison vs.
  GitHub-hosted runners, security notes, and troubleshooting guide.

[Unreleased]: https://github.com/jetonecloud/github-runner-ami/commits/main
