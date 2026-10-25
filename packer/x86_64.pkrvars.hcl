# Build matrix: x86_64
#
# Usage:
#   packer build -var-file=packer/x86_64.pkrvars.hcl packer/

arch          = "x86_64"
instance_type = "t3.medium"
