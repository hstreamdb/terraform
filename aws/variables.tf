// ==== general config ====

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "image_id" {
  description = "System image id."
  type        = string
}

variable "key_pair_name" {
  description = "Name of the key pairs used to access remote server."
  type        = string
}

variable "vpc_cidr_block" {
  type    = string
  default = "172.31.0.0/16"
}

variable "vpc_name" {
  type    = string
  default = "hstream"
}

variable "subnet_cidr_block" {
  type    = string
  default = "172.31.0.0/16"
}

variable "private_key_path" {
  type = string
}

variable "delete_block_on_termination" {
  type = bool
}

// ==== store node config ====

variable "store_config" {
  type = object({
    node_count    = number
    instance_type = string
    volume_size   = number
    volume_type   = string
    iops          = number
    throughput    = number
  })
}

// ==== compute node config ====

variable "cal_config" {
  type = object({
    node_count    = number
    instance_type = string
    volume_size   = number
    volume_type   = string
    iops          = number
    throughput    = number
  })
}

// ==== Security Group ====

variable "security_group_name" {
  type        = string
  default     = "hstream"
  description = "security group name"
}

variable "ingress_rules" {
  type        = list(any)
  default     = [null]
  description = "ingress with cidr blocks"
}

variable "egress_rules" {
  type        = list(any)
  default     = [null]
  description = "egress with cidr blocks"
}
