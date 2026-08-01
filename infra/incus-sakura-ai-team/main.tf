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

resource "incus_instance" "sakura_ai_agent" {
  for_each = var.agents

  name     = each.value.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default"]

  config = {
    "limits.cpu"    = tostring(each.value.cpu_count)
    "limits.memory" = each.value.memory_limit

    "cloud-init.user-data" = templatefile(
      "${path.module}/cloud-init.yaml.tftpl",
      {
        agent_role            = each.value.role
        install_dotnet_sdk     = each.value.install_dotnet_sdk
        sakura_ai_base_url     = var.sakura_ai_base_url
        sakura_ai_token_base64 = base64encode(var.sakura_ai_token)
        sakura_ai_model        = var.sakura_ai_model
        workspace_directory    = var.container_workspace_path
      }
    )
  }

  device {
    name = "experiment-workspace"
    type = "disk"

    properties = {
      source = var.experiment_root
      path   = var.container_workspace_path
      shift  = "true"
    }
  }
}