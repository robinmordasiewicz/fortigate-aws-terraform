resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key" {
  filename        = "deploy-key.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "deployer" {
  key_name_prefix = "fortinet-deploy-"
  public_key      = tls_private_key.ssh_key.public_key_openssh
}
resource "random_password" "admin_password" {
  length           = 16
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  special          = false
  override_special = "-_<>"
}
