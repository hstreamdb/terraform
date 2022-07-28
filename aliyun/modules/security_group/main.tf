resource "alicloud_security_group" "hstream" {
  name                = "hstream"
  vpc_id              = var.vpc_id
  security_group_type = "normal"
}

resource "alicloud_security_group_rule" "hstream_ingress" {
  count = length(var.ingress_with_cidr_blocks)

  type              = "ingress"
  security_group_id = alicloud_security_group.hstream.id
  ip_protocol       = var.ingress_with_cidr_blocks[count.index].ip_protocol
  port_range        = var.ingress_with_cidr_blocks[count.index].port_range
  cidr_ip           = var.ingress_with_cidr_blocks[count.index].cidr_ip
  description       = var.ingress_with_cidr_blocks[count.index].description
}

resource "alicloud_security_group_rule" "hstream_egress" {
  count = length(var.egress_with_cidr_blocks)

  type              = "egress"
  security_group_id = alicloud_security_group.hstream.id
  ip_protocol       = var.egress_with_cidr_blocks[count.index].protocol
  port_range        = var.egress_with_cidr_blocks[count.index].port_range
  cidr_ip           = var.egress_with_cidr_blocks[count.index].cidr_ip
  description       = var.egress_with_cidr_blocks[count.index].description
}