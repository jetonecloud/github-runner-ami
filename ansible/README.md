# Ansible provisioning (alternative to the shell scripts)

The default build (`.github/workflows/build-ami.yml`, `packer build packer/`) uses the
numbered shell scripts in [`packer/scripts/`](../packer/scripts). This playbook is a
drop-in equivalent for teams that standardize on Ansible for configuration management.
Role order mirrors the shell script numbering exactly, and the two paths produce the
same image:

| Shell script                              | Ansible role         |
| ------------------------------------------ | --------------------- |
| `00-system-update.sh`, `10-install-base-packages.sh` | `common`       |
| `20-install-docker.sh`                     | `docker`              |
| `30-install-awscli.sh`                     | `awscli`               |
| `40-install-node.sh`                       | `node`                 |
| `50-install-python.sh`                     | `python`               |
| `60-install-go.sh`                         | `go`                   |
| `70-install-trivy.sh`                      | `trivy`                |
| `80-install-github-runner.sh`, `85-install-runner-service.sh` | `github_runner` |
| `90-security-hardening.sh`                 | `security`             |
| `95-trivy-scan.sh`                         | `trivy_scan`           |
| `99-cleanup.sh`                            | `cleanup`              |

Where a step is mostly a download-and-verify-checksum operation (Node.js, Go, Trivy, the
runner binary), the role uses native Ansible modules (`get_url` with `checksum:`,
`unarchive`). Where the verification logic is non-trivial to express declaratively (the
AWS CLI's GPG signature check, the severity-gated Trivy scan), the role runs the exact
same script used by the shell path (`ansible/roles/awscli/files/install-awscli.sh`,
`ansible/roles/trivy_scan/files/trivy-scan.sh`) so the two provisioning methods can never
silently drift on a security-relevant check. The runner lifecycle files
(`ansible/roles/github_runner/files/*`) are likewise byte-for-byte copies of
[`packer/files/`](../packer/files) - see [CONTRIBUTING.md](../CONTRIBUTING.md) for the
rule that any change to one must be mirrored in the other.

## Using this playbook with Packer

Swap the shell `provisioner` blocks in `packer/build.pkr.hcl` for a single `ansible`
provisioner:

```hcl
provisioner "ansible" {
  playbook_file = "${path.root}/../ansible/playbook.yml"
  extra_arguments = [
    "--extra-vars", "arch=${var.arch} go_arch=${local.go_arch} node_arch=${local.node_arch} runner_arch=${local.runner_arch} trivy_arch=${local.trivy_arch} awscli_arch=${local.awscli_arch}",
    "--extra-vars", "go_version=${var.go_version} go_checksum=${local.go_checksum}",
    "--extra-vars", "node_version=${var.node_version} node_checksum=${local.node_checksum}",
    "--extra-vars", "runner_version=${var.runner_version} runner_checksum=${local.runner_checksum}",
    "--extra-vars", "buildx_version=${var.buildx_version} buildx_checksum=${local.buildx_checksum}",
    "--extra-vars", "trivy_version=${var.trivy_version} trivy_checksum=${local.trivy_checksum} trivy_fail_severity=${var.trivy_fail_severity}",
    "--extra-vars", "awscli_version=${var.awscli_version} awscli_gpg_fingerprint=${var.awscli_gpg_fingerprint}",
  ]
}
```

Requires the `ansible` Packer plugin (`packer init` picks it up once added to
`packer/versions.pkr.hcl`'s `required_plugins`) and a local Ansible installation
reachable from the Packer host.

## Running / testing standalone

```bash
cd ansible
ansible-lint playbook.yml
ansible-playbook --syntax-check playbook.yml
# Against a live host (e.g. a scratch EC2 instance reachable via SSH for testing only):
ansible-playbook -i "<host>," -e arch=x86_64 playbook.yml
```

`group_vars/all.yml` holds the same pinned versions and checksums as
`packer/variables.pkr.hcl` so the playbook is runnable on its own without Packer.
