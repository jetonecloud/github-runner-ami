# Build matrix: arm64 (Graviton)
#
# Usage:
#   packer build -var-file=packer/arm64.pkrvars.hcl packer/

arch          = "arm64"
instance_type = "t4g.medium"
