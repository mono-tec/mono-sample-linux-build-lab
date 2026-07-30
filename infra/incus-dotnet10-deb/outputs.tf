output "instance_name" {
  description = "Created Incus instance name"
  value       = incus_instance.ubuntu2404_dotnet10_deb.name
}