variable "instance_name" {
  description = "Incus instance name"
  type        = string
  default     = "ubuntu2404-dotnet10-deb"
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

  validation {
    condition     = var.cpu_count >= 1
    error_message = "cpu_count must be one or greater."
  }
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
  default     = ""

  validation {
    condition = (
      var.network_mode == "dhcp" ||
      can(cidrhost("${var.guest_ipv4_address}/${var.guest_ipv4_prefix}", 0))
    )
    error_message = "guest_ipv4_address must be a valid IPv4 address when network_mode is static."
  }
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