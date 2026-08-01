output "agents" {
  description = "Created AI agent containers"

  value = {
    for key, instance in incus_instance.sakura_ai_agent :
    key => {
      instance_name      = instance.name
      role               = var.agents[key].role
      cpu_count          = var.agents[key].cpu_count
      memory_limit       = var.agents[key].memory_limit
      install_dotnet_sdk = var.agents[key].install_dotnet_sdk
    }
  }
}

output "sakura_ai_model" {
  description = "Sakura AI Engine model configured for OpenCode"
  value       = var.sakura_ai_model
}

output "experiment_root" {
  description = "Host directory shared with all AI agents"
  value       = var.experiment_root
}

output "container_workspace_path" {
  description = "Shared workspace path inside each container"
  value       = var.container_workspace_path
}