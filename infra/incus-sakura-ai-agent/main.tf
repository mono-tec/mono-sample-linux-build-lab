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

resource "incus_instance" "ubuntu2404_sakura_ai_agent" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default"]

  config = {
    "limits.cpu"    = tostring(var.cpu_count)
    "limits.memory" = var.memory_limit

    "cloud-init.user-data" = templatefile(
      "${path.module}/cloud-init.yaml.tftpl",
      {
        ssh_public_key       = var.ssh_public_key
        guest_interface_name = var.guest_interface_name
        network_mode         = var.network_mode
        guest_ipv4_address   = var.guest_ipv4_address
        guest_ipv4_prefix    = var.guest_ipv4_prefix
        sakura_ai_base_url   = var.sakura_ai_base_url
        sakura_ai_token_base64 = base64encode(var.sakura_ai_token)
        sakura_ai_model      = var.sakura_ai_model
        workspace_directory  = var.workspace_directory
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