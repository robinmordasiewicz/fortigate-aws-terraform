data "aws_ami" "latest" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["FortiGate-VM64-AWS%{if var.license_type == "payg"}ONDEMAND%{endif} * (${var.release})*"]
  }
  filter {
    name   = "architecture"
    values = [var.arch]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_network_interface" "fortigate_external" {
  count             = 2
  description       = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}-external"
  subnet_id         = element([aws_subnet.subnet[0].id, aws_subnet.subnet[3].id], count.index)
  private_ips       = [cidrhost(var.fortigate[count.index].subnet_cidrs.external, 4)]
  security_groups   = [aws_security_group.external_security_group.id]
  source_dest_check = false
  tags              = merge(local.common_tags, { Name = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}-external" })
}

resource "aws_network_interface" "fortigate_internal" {
  count             = 2
  description       = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}-internal"
  subnet_id         = element([aws_subnet.subnet[1].id, aws_subnet.subnet[4].id], count.index)
  private_ips       = [cidrhost(var.fortigate[count.index].subnet_cidrs.internal, 4)]
  source_dest_check = false
  security_groups   = [aws_security_group.internal_security_group.id]
  tags              = merge(local.common_tags, { Name = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}-internal" })
}

resource "aws_network_interface" "fortigate_management" {
  count             = 2
  description       = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}-management"
  subnet_id         = element([aws_subnet.subnet[2].id, aws_subnet.subnet[5].id], count.index)
  private_ips       = [cidrhost(var.fortigate[count.index].subnet_cidrs.management, 4)]
  security_groups   = [aws_security_group.management_security_group.id]
  tags              = merge(local.common_tags, { Name = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}-management" })
  source_dest_check = false
}

resource "aws_instance" "fortigate" {
  count                       = 2
  ami                         = data.aws_ami.latest.id
  instance_type               = var.size
  availability_zone           = element(data.aws_availability_zones.available.names, count.index)
  user_data_replace_on_change = true
  key_name                    = aws_key_pair.deployer.key_name
  iam_instance_profile        = aws_iam_instance_profile.fortinet_iam.id
  tags                        = merge(local.common_tags, { Name = "fortigate-${element(data.aws_availability_zones.available.names, count.index)}" })
  user_data = jsonencode({
    bucket      = aws_s3_bucket.s3_bucket.id,
    region      = var.aws_region,
    license     = var.license_type == "byol" ? "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}.lic" : null,
    config      = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}.conf"
    config_hash = local.fortigate_config_hash
  })
  root_block_device {
    volume_type = "standard"
    volume_size = "2"
  }
  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = "30"
    volume_type = "standard"
  }
  network_interface {
    network_interface_id = aws_network_interface.fortigate_management[count.index].id
    device_index         = tonumber(var.interface_mapping[0].management[0])
  }
  network_interface {
    network_interface_id = aws_network_interface.fortigate_external[count.index].id
    device_index         = tonumber(var.interface_mapping[0].external[0])
  }
  network_interface {
    network_interface_id = aws_network_interface.fortigate_internal[count.index].id
    device_index         = tonumber(var.interface_mapping[0].internal[0])
  }
  metadata_options {
    http_tokens = "required"
  }
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_eip" "management_ip" {
  depends_on                = [aws_internet_gateway.internet_gateway]
  count                     = 2
  domain                    = "vpc"
  network_interface         = aws_network_interface.fortigate_management[count.index].id
  associate_with_private_ip = cidrhost(var.fortigate[count.index].subnet_cidrs.management, 4)
  tags                      = merge(local.common_tags, { Name = "fortigate-${element(data.aws_availability_zones.available.names, count.index)}-management-ip" })
}

resource "aws_eip" "external_floating_ip" {
  depends_on                = [aws_internet_gateway.internet_gateway]
  domain                    = "vpc"
  network_interface         = aws_network_interface.fortigate_external[0].id
  associate_with_private_ip = cidrhost(var.fortigate[0].subnet_cidrs.external, 4)
  tags                      = merge(local.common_tags, { Name = "external_floating_ip" })
}
