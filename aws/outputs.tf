output "storage_instance_public_ip" {
  value = aws_instance.storage_instance[*].public_ip
}

output "storage_instance_access_ip" {
  value = aws_instance.storage_instance[*].private_ip
}

output "calculate_instance_public_ip" {
  value = aws_instance.calculate_instance[*].public_ip
}

output "calculate_instance_access_ip" {
  value = aws_instance.calculate_instance[*].private_ip
}