# outputs.tf — values Terraform prints after `apply`. Useful for the next
# phase's Ansible inventory and for a quick SSH check right after provisioning.

output "ec2_public_ip" {
  description = "Public IPv4 address of the EC2 instance."
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance."
  value       = aws_instance.app.public_dns
}

output "ec2_instance_id" {
  description = "AWS instance ID (handy for aws ec2 describe-instances)."
  value       = aws_instance.app.id
}

output "ssh_command" {
  description = "Copy-paste ready SSH command."
  value       = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ubuntu@${aws_instance.app.public_ip}"
}
