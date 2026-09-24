terraform {
  required_version = ">= 1.8.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 0.5.1"
    }
  }
}

provider "incus" {}

resource "incus_instance" "postgresql_lab" {
  name     = var.container_name
  image    = var.image
  type     = "container"
  profiles = ["default"]

  config = {
    "limits.cpu"    = var.cpu_limit
    "limits.memory" = var.memory_limit

    "cloud-init.user-data" = templatefile(
      "${path.module}/cloud-init.yaml.tftpl",
      {
        postgresql_version = var.postgresql_version
        postgres_password  = var.postgres_password

        network_mode       = var.network_mode
        guest_ipv4_address = var.guest_ipv4_address
        guest_ipv4_prefix  = var.guest_ipv4_prefix
      }
    )
  }

  device {
    name = "eth1"
    type = "nic"

    properties = {
      nictype = "macvlan"
      parent  = var.lan_interface
      name    = "eth1"
    }
  }
}
