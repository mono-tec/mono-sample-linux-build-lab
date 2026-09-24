variable "image" {
  description = "Incus image used for the PostgreSQL lab container"
  type        = string
  default     = "images:ubuntu/24.04/cloud"
}

variable "container_name" {
  description = "Incus container name"
  type        = string
  default     = "ubuntu2404-postgresql17-lab"
}

variable "cpu_limit" {
  description = "Container CPU limit"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Container memory limit"
  type        = string
  default     = "2GiB"
}

variable "lan_interface" {
  description = "Physical LAN interface on the Ubuntu host used by the macvlan NIC"
  type        = string
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
  description = "Static IPv4 address for eth1 when network_mode is static"
  type        = string
  default     = ""
}

variable "guest_ipv4_prefix" {
  description = "IPv4 prefix length for eth1 when network_mode is static"
  type        = number
  default     = 24
}

variable "postgresql_version" {
  description = "PostgreSQL major version installed from the PGDG repository"
  type        = string
  default     = "17"
}

variable "postgres_password" {
  description = "Password assigned to the PostgreSQL postgres administrator role"
  type        = string
  sensitive   = true
}
