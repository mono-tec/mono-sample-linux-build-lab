variable "instance_name" {
  description = "Incus instance name"
  type        = string
  default     = "ubuntu2404-usb-camera"
}

variable "image" {
  description = "Incus cloud image alias"
  type        = string
  default     = "images:ubuntu/24.04/cloud"
}

variable "cpu_count" {
  description = "Number of virtual CPUs assigned to the container"
  type        = number
  default     = 2
}

variable "memory_limit" {
  description = "Memory limit assigned to the container"
  type        = string
  default     = "2GiB"
}

variable "ssh_public_key" {
  description = "SSH public key registered for the ubuntu user"
  type        = string
  sensitive   = true
}

variable "lan_device_name" {
  description = "Incus device name for the LAN interface"
  type        = string
  default     = "lan0"
}

variable "lan_interface" {
  description = "Host physical network interface connected to the LAN"
  type        = string
  default     = "eno1"
}

variable "guest_interface_name" {
  description = "Network interface name inside the Incus container"
  type        = string
  default     = "eth1"
}

variable "network_mode" {
  description = "IPv4 configuration mode for eth1: dhcp or static"
  type        = string
  default     = "dhcp"

  validation {
    condition     = contains(["dhcp", "static"], var.network_mode)
    error_message = "network_mode must be either dhcp or static."
  }
}

variable "guest_ipv4_address" {
  description = "Static IPv4 address assigned to eth1"
  type        = string
  default     = "192.168.XXX.XXX"
}

variable "guest_ipv4_prefix" {
  description = "IPv4 prefix length assigned to eth1"
  type        = number
  default     = 24

  validation {
    condition     = var.guest_ipv4_prefix >= 1 && var.guest_ipv4_prefix <= 32
    error_message = "guest_ipv4_prefix must be between 1 and 32."
  }
}

variable "github_repository" {
  description = "GitHub repository containing the deb package release asset"
  type        = string
  default     = "mono-tec/mono-sample-linux-build-lab"
}

variable "package_version" {
  description = "Version of the deb package downloaded from GitHub Release"
  type        = string
  default     = "0.3.1"

  validation {
    condition = can(
      regex(
        "^[0-9]+\\.[0-9]+\\.[0-9]+([-.][0-9A-Za-z.-]+)?$",
        var.package_version
      )
    )

    error_message = "package_version must use a format such as 0.3.0."
  }
}

variable "package_name" {
  description = "Name of the deb package downloaded from GitHub Release"
  type        = string
  default     = "linux-build-lab-camera"
}

variable "camera_device_name" {
  description = "Incus device name used for the USB camera"
  type        = string
  default     = "camera0"
}

variable "camera_source_path" {
  description = "Video device path on the Ubuntu host"
  type        = string
  default     = "/dev/video0"

  validation {
    condition     = startswith(var.camera_source_path, "/dev/")
    error_message = "camera_source_path must be a device path under /dev."
  }
}

variable "camera_guest_path" {
  description = "Video device path inside the Incus container"
  type        = string
  default     = "/dev/video0"

  validation {
    condition     = startswith(var.camera_guest_path, "/dev/")
    error_message = "camera_guest_path must be a device path under /dev."
  }
}

variable "camera_group_id" {
  description = "GID of the video group inside the Incus container"
  type        = number
  default     = 44

  validation {
    condition     = var.camera_group_id >= 0
    error_message = "camera_group_id must be zero or greater."
  }
}

variable "camera_device_mode" {
  description = "Permission mode assigned to the camera device"
  type        = string
  default     = "0660"

  validation {
    condition     = can(regex("^0[0-7]{3}$", var.camera_device_mode))
    error_message = "camera_device_mode must use a format such as 0660."
  }
}