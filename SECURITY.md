# Security Policy

## Supported Versions

This project ships versioned AMI releases (see [CHANGELOG.md](CHANGELOG.md)). Only the
latest tagged release and the `main` branch receive security fixes. Because the AMI is
rebuilt weekly against the latest Amazon Linux 2023 packages and a pinned GitHub Actions
runner version, we strongly recommend always running the most recently published AMI.

| Version          | Supported          |
| ---------------- | ------------------- |
| Latest tag / main | :white_check_mark: |
| Older tags        | :x:                 |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Instead, report it using one of the following private channels:

1. **GitHub Security Advisories** (preferred): open a draft advisory at
   `https://github.com/jetonecloud/github-runner-ami/security/advisories/new`.
2. **Email**: send details to **security@jetone.com** with a subject line prefixed
   `[github-runner-ami security]`. Include:
   - A description of the vulnerability and its impact.
   - Steps to reproduce (Packer/Terraform versions, AMI build ID, relevant logs).
   - Any suggested remediation, if known.

We will acknowledge your report within **3 business days**, provide an initial
assessment within **7 business days**, and keep you updated on remediation progress
until resolution. We request a 90-day disclosure window before any public write-up,
and are happy to credit reporters who wish to be acknowledged.

## Scope

In scope:
- Packer build logic and provisioning scripts (`packer/`, `ansible/`)
- Runner lifecycle / systemd units (`packer/files`)
- Terraform module and examples (`terraform/`)
- CI/CD pipeline definitions (`.github/workflows/`)

Out of scope:
- Vulnerabilities in upstream software this project installs (Docker, Node.js, Go,
  Trivy, the GitHub Actions runner itself, Amazon Linux packages). Please report those
  to the respective upstream project, though we appreciate a heads-up so we can rebuild.
- Issues requiring privileged AWS account access the reporter does not have
  authorization to use.

## Security Design Notes

See [docs/security.md](docs/security.md) for the threat model and hardening details
(IMDSv2 enforcement, SSM-only access, least-privilege IAM, encrypted volumes, secret
handling, and the ephemeral single-job lifecycle that limits persistence).
