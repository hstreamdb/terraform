variable "vpc_id" {
  type = string
}

variable "ingress_with_cidr_blocks" {
  type = list(any)
}

variable "egress_with_cidr_blocks" {
  type = list(any)
}