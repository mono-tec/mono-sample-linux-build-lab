variable "instance_name" {
  description = "Incus instance name"
  type        = string
  default     = "ubuntu2404-sakura-ai-agent"
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
  default     = "4GiB"

  validation {
    condition = can(
      regex(
        "^[1-9][0-9]*(MiB|GiB)$",
        var.memory_limit
      )
    )

    error_message = "memory_limit must use a format such as 2048MiB or 4GiB."
  }
}

variable "ssh_public_key" {
  description = "SSH public key registered for the ubuntu user"
  type        = string
  sensitive   = true

  validation {
    condition = can(
      regex(
        "^ssh-(ed25519|rsa|ecdsa)[[:space:]]+",
        var.ssh_public_key
      )
    )

    error_message = "ssh_public_key must be a valid OpenSSH public key."
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
  description = "IPv4 configuration mode for the LAN interface: dhcp or static"
  type        = string
  default     = "dhcp"

  validation {
    condition     = contains(["dhcp", "static"], var.network_mode)
    error_message = "network_mode must be either dhcp or static."
  }
}

variable "guest_ipv4_address" {
  description = "Static IPv4 address assigned to the LAN interface"
  type        = string
  default     = ""

  validation {
    condition = (
      var.network_mode == "dhcp" ||
      can(cidrhost("${var.guest_ipv4_address}/32", 0))
    )

    error_message = "guest_ipv4_address must be a valid IPv4 address when network_mode is static."
  }
}

variable "guest_ipv4_prefix" {
  description = "IPv4 prefix length assigned to the LAN interface"
  type        = number
  default     = 24

  validation {
    condition = (
      var.guest_ipv4_prefix >= 1 &&
      var.guest_ipv4_prefix <= 32
    )

    error_message = "guest_ipv4_prefix must be between 1 and 32."
  }
}

variable "sakura_ai_base_url" {
  description = "Base URL of Sakura AI Engine"
  type        = string
  default     = "https://api.ai.sakura.ad.jp/v1"

  validation {
    condition     = can(regex("^https://", var.sakura_ai_base_url))
    error_message = "sakura_ai_base_url must start with https://."
  }
}

variable "sakura_ai_token" {
  description = "Account token used to access Sakura AI Engine"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.sakura_ai_token)) > 0
    error_message = "sakura_ai_token must not be empty."
  }
}

variable "sakura_ai_model" {
  description = "Sakura AI Engine model used by OpenCode"
  type        = string
  default     = "preview/Kimi-K2.7-Code"

  validation {
    condition = contains(
      [
        "preview/Kimi-K2.7-Code",
        "gpt-oss-120b",
        "llm-jp-3.1-8x13b-instruct4",
        "preview/Kimi-K2.6"
      ],
      var.sakura_ai_model
    )

    error_message = "sakura_ai_model must be one of the supported Sakura AI Engine models."
  }
}

variable "workspace_directory" {
  description = "Working directory used by OpenCode"
  type        = string
  default     = "/home/ubuntu/workspace"

  validation {
    condition = (
      startswith(var.workspace_directory, "/home/ubuntu/") &&
      !endswith(var.workspace_directory, "/..")
    )

    error_message = "workspace_directory must be under /home/ubuntu."
  }
}