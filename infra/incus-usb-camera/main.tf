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

resource "incus_instance" "ubuntu2404_usb_camera" {
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
        ssh_public_key     = var.ssh_public_key

        network_mode       = var.network_mode
        guest_ipv4_address = var.guest_ipv4_address
        guest_ipv4_prefix  = var.guest_ipv4_prefix
      }
    )
  }

  # Windows PCと同じ物理LANへ接続するためのNICです。
  device {
    name = var.lan_device_name
    type = "nic"

    properties = {
      nictype = "macvlan"
      parent  = var.lan_interface
      name    = var.guest_interface_name
    }
  }

  # Ubuntuホストの映像デバイスを
  # IncusコンテナへUnix character deviceとして割り当てます。
  device {
    name = var.camera_device_name
    type = "unix-char"

    properties = {
      source = var.camera_source_path
      path   = var.camera_guest_path

      # コンテナ内のvideoグループへ所有権を割り当てます。
      gid = tostring(var.camera_group_id)

      # rootユーザーとvideoグループへ
      # 読み書き権限を与えます。
      mode = var.camera_device_mode
    }
  }
}