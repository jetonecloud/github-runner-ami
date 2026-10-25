#!/usr/bin/env bash
# Python 3 + pip/venv from the AL2023 repos (already security-patched by
# 00-system-update.sh).
set -euo pipefail

dnf -y install python3 python3-pip python3-setuptools python3-virtualenv

python3 -m pip install --upgrade --no-cache-dir pip

ln -sf /usr/bin/python3 /usr/local/bin/python

python3 --version
pip3 --version
