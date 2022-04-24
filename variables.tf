// ==== general config ====

variable "region_name" {
    type = string
}
variable "region_network_type" {
    type = string
}

variable "image_name" {
  description = "The system image."
  type        = string
}

variable "key_pair_name" {
  type        = string
}

variable "network_uuid" {
    type = string
}

variable "security_group_ids" {
    type = string
}

variable "private_key_path" {
    type = string
    default = null
}

// ==== server config ====

variable "server_config" {
  type = object({
      node_count = number
      flavor_name = string
      data_disk_type = string
      data_disk_size = number
      system_disk_type = string
      system_disk_size = number
  })
}

// ==== client config ====

variable "client_config" {
  type = object({
      node_count = number
      flavor_name = string
      data_disk_type = string
      data_disk_size = number
      system_disk_type = string
      system_disk_size = number
  })
}
