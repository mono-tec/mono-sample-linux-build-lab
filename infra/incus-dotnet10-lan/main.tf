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

resource "incus_instance" "ubuntu2404_dotnet10_lan" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default"]

  config = {
    "limits.cpu"    = tostring(var.cpu_count)
    "limits.memory" = var.memory_limit

    "cloud-init.user-data" = templatefile(
      "${path.module}/cloud-init.yaml",
      {
        ssh_public_key    = var.ssh_public_key
        github_repository = var.github_repository
        release_version   = var.release_version
        release_asset_name = var.release_asset_name
      }
    )
  }

  device {
    name = var.lan_device_name
    type = "nic"

    properties = {
      nictype = "macvlan"
      parent  = var.lan_interface
      name    = var.guest_interface_name
    }
  }
}