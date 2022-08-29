variable "vpc_id" {
  type = string
}

variable "ingress_rules" {
  type = list(any)
}

variable "egress_rules" {
  type = list(any)
}

variable "sg_name" {
  type = string
}