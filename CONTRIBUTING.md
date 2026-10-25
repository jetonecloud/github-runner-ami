# Contributing to github-runner-ami

Thanks for considering a contribution! This project builds an Amazon Linux 2023 AMI for
ephemeral, self-hosted GitHub Actions runners using Packer, with Terraform modules to
deploy it. Contributions of all sizes are welcome: bug fixes, new provisioning steps,
docs, and CI improvements.

## Ways to contribute

- **Bug reports**: open an issue with repro steps, the arch (`x86_64`/`arm64`), Packer
  version, and relevant log output.
- **Feature requests**: open an issue describing the use case before submitting a large
  PR, so we can discuss design/scope first.
- **Pull requests**: see workflow below.

## Development setup

You'll need:

- [Packer](https://developer.hashicorp.com/packer/downloads) >= 1.10
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.7
- [shellcheck](https://www.shellcheck.net/) for shell script linting
- [tflint](https://github.com/terraform-linters/tflint) for Terraform linting
- `ansible-lint` if you touch the `ansible/` playbooks
- An AWS account with permissions to build AMIs (EC2, IAM read, SSM) for integration
  testing

Clone the repo and run the local validation suite before opening a PR:

```bash
# Format & validate Packer
packer fmt -check -recursive packer/
packer validate -var-file=packer/x86_64.auto.pkrvars.hcl packer/

# Lint shell scripts
shellcheck packer/scripts/*.sh packer/files/scripts/*.sh test/smoke-test.sh

# Format & validate Terraform
terraform fmt -check -recursive terraform/
terraform -chdir=terraform/modules/github-runner-asg validate
terraform -chdir=terraform/examples/basic validate

# Lint Ansible (optional provisioner path)
ansible-lint ansible/playbook.yml
```

These are the same checks run by `.github/workflows/validate.yml`.

## Making changes

1. Fork the repo and create a branch off `main`: `git checkout -b my-change`.
2. Keep changes focused — one logical change per PR makes review and rollback easier.
3. Update documentation (`README.md`, `docs/`) when you change behavior, variables, or
   the file layout.
4. Pin any new third-party binary by version **and** checksum (see
   `packer/variables.pkr.hcl` for the pattern used for the runner, Node.js, Go, and
   Trivy). Do not add unpinned `curl | bash` installs.
5. If you add a provisioning step, mirror it in both the shell scripts
   (`packer/scripts/`) and the Ansible role (`ansible/roles/`) so the two provisioning
   paths stay equivalent — see `README.md#provisioning-methods`.
6. Run the local validation commands above.
7. If your change affects the runner lifecycle, IAM policy, or networking, consider
   running the smoke test (`test/smoke-test.sh`) against a scratch AWS account/test repo.

## Commit messages

Use short, imperative subject lines (e.g. `Add Trivy severity gate to build pipeline`).
Reference the issue number when applicable. Do not attribute commits to any AI tool;
list yourself as the author.

## Pull request process

1. Ensure CI (`validate.yml`) passes.
2. Describe **what** changed and **why**, and call out any security-relevant impact
   (new IAM permissions, new network paths, new installed software).
3. A maintainer will review within a few business days. We may ask for the smoke test
   output on real AWS infrastructure for changes to the runner lifecycle or Terraform
   module.
4. Once approved, a maintainer will merge. AMI rebuilds happen automatically on `main`
   and weekly via `weekly-rebuild.yml`.

## Reporting security issues

Do not open public issues for vulnerabilities — see [SECURITY.md](SECURITY.md).

## Code of conduct

Be respectful and constructive. We follow the spirit of the
[Contributor Covenant](https://www.contributor-covenant.org/) — harassment, personal
attacks, and discriminatory language will not be tolerated.
