packer {
  required_version = ">= 1.10.0"

  required_plugins {
    amazon = {
      version = ">= 1.3.3, < 2.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}
