variable "instance_name" {
  description = "Incus instance name"
  type        = string
  default     = "ubuntu2404-dotnet10-lan"
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