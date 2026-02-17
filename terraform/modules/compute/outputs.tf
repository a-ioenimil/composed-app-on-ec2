output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2-instance.id
}

output "public_ip" {
  description = "Public IP address"
  value       = module.ec2-instance.public_ip
}

output "public_dns" {
  description = "Public DNS name"
  value       = module.ec2-instance.public_dns
}
