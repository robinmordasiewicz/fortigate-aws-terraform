data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "security-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = merge(local.common_tags, { Name = "${var.vpc_name}-vpc" })
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.security-vpc.id
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-internet_gateway" })
}

resource "aws_subnet" "subnet" {
  count             = length(var.fortigate) * length(var.subnet_types)
  cidr_block        = var.fortigate[floor(count.index / length(var.subnet_types))].subnet_cidrs[var.subnet_types[count.index % length(var.subnet_types)]]
  vpc_id            = aws_vpc.security-vpc.id
  availability_zone = count.index < local.half_count ? data.aws_availability_zones.available.names[0] : data.aws_availability_zones.available.names[1]
  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-${var.subnet_types[count.index % length(var.subnet_types)]}-${count.index < local.half_count ? data.aws_availability_zones.available.names[0] : data.aws_availability_zones.available.names[1]}"
  })
}

locals {
  half_count = length(var.fortigate) * length(var.subnet_types) / 2
}

resource "aws_ec2_transit_gateway" "transit_gateway" {
  description                     = "Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  amazon_side_asn                 = var.transit_gateway_amazon_side_asn
  #transit_gateway_cidr_blocks     = [for fortigate in var.fortigate : fortigate.subnet_cidrs.transit]
  transit_gateway_cidr_blocks    = ["1.0.0.0/24"]
  tags                           = merge(local.common_tags, { Name = "${var.vpc_name}-tgw" })
  auto_accept_shared_attachments = "enable"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "security_vpc_attachment" {
  appliance_mode_support = "enable"
  subnet_ids             = [aws_subnet.subnet[1].id, aws_subnet.subnet[4].id]
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id                 = aws_vpc.security-vpc.id
  tags                   = merge(local.common_tags, { Name = "${var.vpc_name}-security_vpc_attachment" })
}

resource "aws_ec2_transit_gateway_connect" "tgw_connect" {
  transport_attachment_id                         = aws_ec2_transit_gateway_vpc_attachment.security_vpc_attachment.id
  transit_gateway_id                              = aws_ec2_transit_gateway.transit_gateway.id
  tags                                            = merge(local.common_tags, { Name = "${var.vpc_name}-tgw-gre-connect" })
  transit_gateway_default_route_table_propagation = true ## IS this needed
}

resource "aws_ec2_transit_gateway_connect_peer" "fortigate" {
  count                         = length(var.fortigate)
  peer_address                  = cidrhost(var.fortigate[count.index].subnet_cidrs.internal, 4)
  bgp_asn                       = var.fortigate[count.index].bgp_asn
  transit_gateway_address       = cidrhost(var.fortigate[count.index].subnet_cidrs.transit, 68 + count.index)
  inside_cidr_blocks            = var.fortigate[count.index].inside_cidr_blocks
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.tgw_connect.id
  tags                          = merge(local.common_tags, { Name = "fortigate-${element(data.aws_availability_zones.available.names, count.index)}-peer" })
}

resource "aws_route_table" "management_route_table" {
  vpc_id = aws_vpc.security-vpc.id
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-management_route_table" })
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table" "external_route_table" {
  vpc_id = aws_vpc.security-vpc.id
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-external_route_table" })
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table" "internal_route_table" {
  vpc_id = aws_vpc.security-vpc.id
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-internal_route_table" })
  route {
    cidr_block = var.fortigate[0].subnet_cidrs.transit
    #network_interface_id = aws_network_interface.fortigate_internal[0].id
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  }
}

resource "aws_route_table" "transit_route_table" {
  vpc_id = aws_vpc.security-vpc.id
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-transit_route_table" })
}

resource "aws_route_table_association" "zone-1-external_route_table_association" {
  route_table_id = aws_route_table.external_route_table.id
  subnet_id      = aws_subnet.subnet[0].id
}

resource "aws_route_table_association" "zone-1-internal_route_table_association" {
  route_table_id = aws_route_table.internal_route_table.id
  subnet_id      = aws_subnet.subnet[1].id
}

resource "aws_route_table_association" "zone-1-management_route_table_association" {
  route_table_id = aws_route_table.management_route_table.id
  subnet_id      = aws_subnet.subnet[2].id
}

resource "aws_route_table_association" "zone-2-external_route_table_association" {
  route_table_id = aws_route_table.external_route_table.id
  subnet_id      = aws_subnet.subnet[3].id
}

resource "aws_route_table_association" "zone-2-internal_route_table_association" {
  route_table_id = aws_route_table.internal_route_table.id
  subnet_id      = aws_subnet.subnet[4].id
}

resource "aws_route_table_association" "zone-2-management_route_table_association" {
  route_table_id = aws_route_table.management_route_table.id
  subnet_id      = aws_subnet.subnet[5].id
}

resource "aws_security_group" "management_security_group" {
  name        = "management_security_group"
  description = "Allow SSH, HTTPS and ICMP"
  vpc_id      = aws_vpc.security-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "management_security_group" })
}

resource "aws_security_group" "external_security_group" {
  name        = "external_security_group"
  description = "Allow SSH, HTTPS and ICMP traffic from external"
  vpc_id      = aws_vpc.security-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "external_security_group" })
}

resource "aws_security_group" "internal_security_group" {
  name        = "internal_security_group"
  description = "Allow all traffic from VPC"
  vpc_id      = aws_vpc.security-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "internal_security_group" })
}
