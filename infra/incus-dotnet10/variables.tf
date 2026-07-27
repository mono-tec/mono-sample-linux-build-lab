variable "instance_name" {
  description = "Incus instance name"
  type        = string
  default     = "ubuntu2404-dotnet10"
}

variable "image" {
  description = "Incus image alias"
  type        = string
  default     = "images:ubuntu/24.04"
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