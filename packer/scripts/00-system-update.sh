#!/usr/bin/env bash
# Patch the base Amazon Linux 2023 image to the latest packages before
# installing anything else, so the AMI starts from a current baseline.
set -euo pipefail

dnf -y update
dnf -y install dnf-plugins-core
dnf clean all
