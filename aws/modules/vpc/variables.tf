variable "vpc_name" {
  type    = string
  default = "hstream"
}

variable "vpc_cidr_block" {
  type    = string
  default = "172.31.0.0/16"
}

variable "subnet_cidr_block" {
  type    = string
  default = "172.31.0.0/16"
}

variable "zone" {
  type = string
}