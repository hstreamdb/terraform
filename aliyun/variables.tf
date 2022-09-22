## Common

variable "region" {
  type        = string
  description = "region name"
  default     = "cn-hangzhou"
  sensitive   = true
}

variable "zone" {
  type        = string
  description = "zone name"
  default     = "cn-hangzhou-i"
  sensitive   = true
}

variable "image_id" {
  type        = string
  default     = "ubuntu_20_04_x64_20G_alibase_20210623.vhd"
  description = "image id"
}

variable "key_pair_name" {
  type      = string
  sensitive = true
}

variable "private_key_path" {
  type      = string
  sensitive = true
}

## Vpc

variable "ecs_vswitch_conf" {
  type = object({
    name   = string
    region = string
    cidr   = string
  })
  description = "vswitch configurations"
}

variable "vpc_cidr_block" {
  type        = string
  default     = ""
  description = "cidr of vpc"
}

variable "vsw_cidr_block" {
  type        = string
  default     = ""
  description = "cidr of vsw"
}

## Security Group

variable "security_group_name" {
  type        = string
  default     = "hstream"
  description = "security group name"
}

variable "ingress_with_cidr_blocks" {
  type        = list(any)
  default     = [null]
  description = "ingress with cidr blocks"
}

variable "egress_with_cidr_blocks" {
  type        = list(any)
  default     = [null]
  description = "egress with cidr blocks"
}

## Ecs

variable "storage_instance_config" {
  type = object({
    node_count           = number
    instance_type        = string
    system_disk_category = string
    system_disk_size     = number
  })
}

variable "calculate_instance_config" {
  type = object({
    node_count           = number
    instance_type        = string
    system_disk_category = string
    system_disk_size     = number
  })
}

variable "storage_instance_type" {
  type        = string
  default     = "ecs.i2gne.2xlarge"
  description = "hstream-server instance type"
}

variable "calculate_instance_type" {
  type        = string
  default     = "ecs.i2gne.2xlarge"
  description = "hstream-server instance type"
}

variable "internet_max_bandwidth_out" {
  type        = number
  default     = 10
  description = "internet max bandwidth out"
}

variable "internet_charge_type" {
  type        = string
  default     = "PayByTraffic"
  description = "charge type"
}

## clb

variable "listener_tcp_ports" {
  type        = list(number)
  default     = []
  description = "the tcp listener ports of clb"
}

variable "listener_http_ports" {
  type        = list(number)
  default     = []
  description = "the http listener ports of clb"
}