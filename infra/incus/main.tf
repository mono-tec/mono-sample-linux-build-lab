terraform {
  required_version = ">= 1.8.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 0.4"
    }
  }
}

provider "incus" {}

resource "incus_instance" "ubuntu2404" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default"]

  config = {
    "limits.cpu"    = tostring(var.cpu_count)
    "limits.memory" = var.memory_limit
  }
}
