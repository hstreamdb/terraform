output "node_info" {
  value = merge(
    {
      for idx, n in aws_instance.storage_instance.* : "hs-s${idx + 1}" => {
        public_ip     = n.public_ip
        access_ip     = n.private_ip
        instance_type = n.instance_type
      }
    },
    {
      for idx, n in aws_instance.calculate_instance.* : "hs-c${idx + 1}" => {
        public_ip     = n.public_ip
        access_ip     = n.private_ip
        instance_type = n.instance_type
      }
    },
  )
}