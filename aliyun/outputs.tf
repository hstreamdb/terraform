output "vpc_id" {
  value = module.ali_vpc.vpc_id
}

output "vsw_id" {
  value = module.ali_vpc.vsw_id
}

output "server_public_ip" {
  value = alicloud_instance.storage_instance[*].public_ip
}

output "server_access_ip" {
  value = alicloud_instance.storage_instance[*].private_ip
}

output "client_public_ip" {
  value = alicloud_instance.calculate_instance[*].public_ip
}

output "client_access_ip" {
  value = alicloud_instance.calculate_instance[*].private_ip
}

