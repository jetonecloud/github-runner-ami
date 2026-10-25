locals {
  # Per-arch tokens for upstream download URLs, since every vendor spells
  # architecture differently. Resolved once here so provisioning scripts never
  # branch on var.arch themselves.
  go_arch     = var.arch == "arm64" ? "arm64" : "amd64"
  node_arch   = var.arch == "arm64" ? "arm64" : "x64"
  runner_arch = var.arch == "arm64" ? "arm64" : "x64"
  trivy_arch  = var.arch == "arm64" ? "ARM64" : "64bit"
  awscli_arch = var.arch == "arm64" ? "aarch64" : "x86_64"

  go_checksum     = var.arch == "arm64" ? var.go_checksum_arm64 : var.go_checksum_amd64
  node_checksum   = var.arch == "arm64" ? var.node_checksum_arm64 : var.node_checksum_x64
  runner_checksum = var.arch == "arm64" ? var.runner_checksum_arm64 : var.runner_checksum_x64
  trivy_checksum  = var.arch == "arm64" ? var.trivy_checksum_arm64 : var.trivy_checksum_x64
  buildx_checksum = var.arch == "arm64" ? var.buildx_checksum_arm64 : var.buildx_checksum_amd64

  provision_env = [
    "ARCH=${var.arch}",
    "GO_ARCH=${local.go_arch}",
    "NODE_ARCH=${local.node_arch}",
    "RUNNER_ARCH=${local.runner_arch}",
    "TRIVY_ARCH=${local.trivy_arch}",
    "AWSCLI_ARCH=${local.awscli_arch}",
    "GO_VERSION=${var.go_version}",
    "GO_CHECKSUM=${local.go_checksum}",
    "NODE_VERSION=${var.node_version}",
    "NODE_CHECKSUM=${local.node_checksum}",
    "RUNNER_VERSION=${var.runner_version}",
    "RUNNER_CHECKSUM=${local.runner_checksum}",
    "TRIVY_VERSION=${var.trivy_version}",
    "TRIVY_CHECKSUM=${local.trivy_checksum}",
    "BUILDX_VERSION=${var.buildx_version}",
    "BUILDX_CHECKSUM=${local.buildx_checksum}",
    "TRIVY_FAIL_SEVERITY=${var.trivy_fail_severity}",
    "AWSCLI_VERSION=${var.awscli_version}",
    "AWSCLI_GPG_FINGERPRINT=${var.awscli_gpg_fingerprint}",
  ]
}

build {
  name    = "github-runner-ami"
  sources = ["source.amazon-ebs.github_runner"]

  # Stage our systemd units, runner lifecycle scripts, and Docker config so
  # the shell provisioners below can install them with the right owner/mode.
  provisioner "file" {
    source      = "${path.root}/files/"
    destination = "/tmp/packer-files"
  }

  provisioner "shell" {
    environment_vars = local.provision_env
    execute_command  = "chmod +x {{ .Path }}; sudo -E {{ .Path }}"
    scripts = [
      "${path.root}/scripts/00-system-update.sh",
      "${path.root}/scripts/10-install-base-packages.sh",
      "${path.root}/scripts/20-install-docker.sh",
      "${path.root}/scripts/30-install-awscli.sh",
      "${path.root}/scripts/40-install-node.sh",
      "${path.root}/scripts/50-install-python.sh",
      "${path.root}/scripts/60-install-go.sh",
      "${path.root}/scripts/70-install-trivy.sh",
      "${path.root}/scripts/80-install-github-runner.sh",
      "${path.root}/scripts/85-install-runner-service.sh",
      "${path.root}/scripts/90-security-hardening.sh",
    ]
  }

  # Trivy filesystem scan runs after every package is installed but before
  # cleanup, so the scan sees the full set of binaries that will ship in the
  # AMI. A HIGH/CRITICAL finding fails the build (see var.trivy_fail_severity).
  provisioner "shell" {
    environment_vars = local.provision_env
    execute_command  = "chmod +x {{ .Path }}; sudo -E {{ .Path }}"
    scripts = [
      "${path.root}/scripts/95-trivy-scan.sh",
    ]
  }

  provisioner "shell" {
    environment_vars = local.provision_env
    execute_command  = "chmod +x {{ .Path }}; sudo -E {{ .Path }}"
    scripts = [
      "${path.root}/scripts/99-cleanup.sh",
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
    custom_data = {
      arch           = var.arch
      ami_version    = var.ami_version
      runner_version = var.runner_version
    }
  }
}
