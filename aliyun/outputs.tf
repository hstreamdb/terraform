output "vpc_id" {
  value = module.ali_vpc.vpc_id
}

output "vsw_id" {
  value = module.ali_vpc.vsw_id
}

output "node_info" {
  value = merge(
    {
      for idx, n in alicloud_instance.storage_instance.* : "hs-s${idx + 1}" => {
        public_ip     = n.public_ip
        access_ip     = n.private_ip
        instance_type = n.instance_type
      }
    },
    {
      for idx, n in alicloud_instance.calculate_instance.* : "hs-c${idx + 1}" => {
        public_ip     = n.public_ip
        access_ip     = n.private_ip
        instance_type = n.instance_type
      }
    },
  )
}

