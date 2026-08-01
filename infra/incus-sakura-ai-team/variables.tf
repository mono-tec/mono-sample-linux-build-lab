# ============================================================
# Incus共通設定
# ============================================================

variable "image" {
  description = "Incus cloud image alias"
  type        = string
  default     = "images:ubuntu/24.04/cloud"

  validation {
    condition     = length(trimspace(var.image)) > 0
    error_message = "image must not be empty."
  }
}

# ============================================================
# AIエージェント設定
# ============================================================

variable "agents" {
  description = "Definitions of AI agent containers"

  type = map(object({
    instance_name      = string
    role               = string
    cpu_count          = number
    memory_limit       = string
    install_dotnet_sdk = bool
  }))

  default = {
    agent01 = {
      instance_name      = "ubuntu2404-sakura-agent-01"
      role               = "design"
      cpu_count          = 1
      memory_limit       = "2GiB"
      install_dotnet_sdk = false
    }

    agent02 = {
      instance_name      = "ubuntu2404-sakura-agent-02"
      role               = "build"
      cpu_count          = 2
      memory_limit       = "4GiB"
      install_dotnet_sdk = true
    }
  }

  validation {
    condition     = length(var.agents) > 0
    error_message = "agents must contain at least one agent."
  }

  validation {
    condition = alltrue([
      for agent in values(var.agents) :
      length(trimspace(agent.instance_name)) > 0
    ])

    error_message = "Every agent instance_name must not be empty."
  }

  validation {
    condition = alltrue([
      for agent in values(var.agents) :
      length(trimspace(agent.role)) > 0
    ])

    error_message = "Every agent role must not be empty."
  }

  validation {
    condition = alltrue([
      for agent in values(var.agents) :
      agent.cpu_count >= 1
    ])

    error_message = "Every agent cpu_count must be one or greater."
  }

  validation {
    condition = alltrue([
      for agent in values(var.agents) :
      can(regex(
        "^[1-9][0-9]*(MiB|GiB)$",
        agent.memory_limit
      ))
    ])

    error_message = "Every agent memory_limit must use a format such as 2048MiB or 2GiB."
  }

  validation {
    condition = (
      length(distinct([
        for agent in values(var.agents) :
        agent.instance_name
      ])) == length(var.agents)
    )

    error_message = "Every agent instance_name must be unique."
  }
}

# ============================================================
# さくらのAI Engine設定
# ============================================================

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
  default     = "preview/Kimi-K2.6"

  validation {
    condition     = length(trimspace(var.sakura_ai_model)) > 0
    error_message = "sakura_ai_model must not be empty."
  }
}

# ============================================================
# AIエージェント共有作業領域
# ============================================================

variable "experiment_root" {
  description = "Host directory containing AI agent experiments"
  type        = string
  default     = "/home/ubuntu/ai-agent-team"

  validation {
    condition = (
      startswith(var.experiment_root, "/") &&
      var.experiment_root != "/"
    )

    error_message = "experiment_root must be an absolute path other than root."
  }
}

variable "container_workspace_path" {
  description = "Path where the shared experiment directory is mounted in each container"
  type        = string
  default     = "/workspace"

  validation {
    condition = (
      startswith(var.container_workspace_path, "/") &&
      var.container_workspace_path != "/"
    )

    error_message = "container_workspace_path must be an absolute path other than root."
  }
}