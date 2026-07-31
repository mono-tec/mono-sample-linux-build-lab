output "instance_name" {
  description = "Created Incus instance name"
  value       = incus_instance.ubuntu2404_sakura_ai_agent.name
}

output "lan_device_name" {
  description = "Incus device name used for the LAN interface"
  value       = var.lan_device_name
}

output "guest_interface_name" {
  description = "Network interface name inside the Incus container"
  value       = var.guest_interface_name
}

output "network_mode" {
  description = "IPv4 configuration mode used by the LAN interface"
  value       = var.network_mode
}

output "configured_ipv4_address" {
  description = "Configured static IPv4 address, or an empty string when DHCP is used"
  value = (
    var.network_mode == "static"
    ? "${var.guest_ipv4_address}/${var.guest_ipv4_prefix}"
    : ""
  )
}

output "sakura_ai_model" {
  description = "Sakura AI Engine model configured for OpenCode"
  value       = var.sakura_ai_model
}

output "workspace_directory" {
  description = "Working directory created for OpenCode"
  value       = var.workspace_directory
}