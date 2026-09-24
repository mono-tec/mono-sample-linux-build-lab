output "instance_name" {
  description = "Created Incus instance name"
  value       = incus_instance.postgresql_lab.name
}

output "dbeaver_connection" {
  description = "DBeaver connection settings. Use the eth1 IPv4 address as Host."
  value = {
    host     = var.network_mode == "static" ? var.guest_ipv4_address : "Check eth1 with: incus exec ${var.container_name} -- ip -4 -br address show eth1"
    port     = 5432
    database = "postgres"
    username = "postgres"
  }
}
