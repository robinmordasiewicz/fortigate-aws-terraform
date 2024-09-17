output "admin_password" {
  description = "Password for admin account"
  value       = random_password.admin_password.result
  sensitive   = true
}

output "fortigate_https" {
  value = join(", ", [for i in range(2) : join("", tolist(["https://", aws_eip.management_ip[i].public_dns, ":", var.admin_sport]))])
}

output "fortigate_ssh" {
  value = join(", ", [for i in range(2) : "ssh -i ${local_file.ssh_private_key.filename} admin@${aws_eip.management_ip[i].public_dns}"])
}
