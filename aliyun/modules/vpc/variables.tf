variable "vpc_name" {
  type    = string
  default = "hstream"
}

variable "vpc_cidr_block" {
  type    = string
  default = "172.80.0.0/12"
}

variable "vsw_cidr_block" {
  type    = string
  default = "172.80.0.0/21"
}

variable "vpc_zone" {
  type    = string
  default = "cn-beijing-b"
}