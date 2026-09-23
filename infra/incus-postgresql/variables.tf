variable "instance_name" {
  description = "Incus instance name"
  type        = string
  default     = "ubuntu2404-postgresql17-lab"
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

variable "postgresql_version" {
  description = "PostgreSQL major version installed from the official PGDG repository"
  type        = number
  default     = 17

  validation {
    condition     = var.postgresql_version >= 13 && var.postgresql_version <= 18
    error_message = "postgresql_version must be between 13 and 18."
  }
}

variable "db_name" {
  description = "Database name used by the lab"
  type        = string
  default     = "labdb"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]*$", var.db_name))
    error_message = "db_name must start with a lowercase letter and contain only lowercase letters, digits, and underscores."
  }
}

variable "db_user" {
  description = "Login role used by DBeaver or PLC"
  type        = string
  default     = "labuser"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]*$", var.db_user))
    error_message = "db_user must start with a lowercase letter and contain only lowercase letters, digits, and underscores."
  }
}

variable "db_password" {
  description = "Password for the PostgreSQL lab login role"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12 && can(regex("^[A-Za-z0-9_-]+$", var.db_password))
    error_message = "db_password must be at least 12 characters and contain only letters, digits, underscores, or hyphens."
  }
}

variable "db_client_cidr" {
  description = "IPv4 CIDR allowed to connect to PostgreSQL. Example: 192.168.1.0/24"
  type        = string
  default     = "192.168.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.db_client_cidr))
    error_message = "db_client_cidr must be a valid IPv4 CIDR such as 192.168.1.0/24."
  }
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
