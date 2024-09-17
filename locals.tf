locals {
  common_tags = {
    company     = var.company
    project     = "${var.company}-${var.project}"
    environment = var.environment
    createdby   = var.createdby
  }
  fortigate_content = [
    for i in range(length(var.fortigate)) : templatefile(var.fortigate_bootstrap, {
      VAR_admin_sport                     = var.admin_sport,
      VAR_bgp_as                          = var.fortigate[i].bgp_asn,
      VAR_defaultgwy                      = cidrhost(var.fortigate[i].subnet_cidrs.external, 1),
      VAR_gre_tunnel_tgwc_local_gw        = cidrhost(var.fortigate[i].subnet_cidrs.internal, 4),
      VAR_gre_tunnel_tgwc_remote_gw       = cidrhost(var.fortigate[i].subnet_cidrs.transit, 68 + i),
      VAR_ha_mgmt_interfaces_gateway_ip   = cidrhost(var.fortigate[i].subnet_cidrs.management, 1),
      VAR_ha_priority                     = var.fortigate[i].priority,
      VAR_hostname                        = "fortigate-${element(data.aws_availability_zones.available.names, i)}",
      VAR_interface_tgwc_ip               = cidrhost(var.fortigate[i].inside_cidr_blocks[0], 1),
      VAR_interface_tgwc_remote_ip        = cidrhost(var.fortigate[i].inside_cidr_blocks[0], 2),
      VAR_internal_gateway                = cidrhost(var.fortigate[i].subnet_cidrs.internal, 1),
      VAR_password                        = random_password.admin_password.result,
      VAR_management_ip                   = cidrhost(var.fortigate[i].subnet_cidrs.management, 4),
      VAR_management_mask                 = cidrnetmask(var.fortigate[i].subnet_cidrs.management),
      VAR_management_port                 = element(var.interface_mapping[0].management, 0) + 1,
      VAR_management_name                 = element(var.interface_mapping[0].management, 1),
      VAR_external_ip                     = cidrhost(var.fortigate[i].subnet_cidrs.external, 4),
      VAR_external_mask                   = cidrnetmask(var.fortigate[i].subnet_cidrs.external),
      VAR_external_port                   = element(var.interface_mapping[0].external, 0) + 1,
      VAR_external_name                   = element(var.interface_mapping[0].external, 1),
      VAR_internal_ip                     = cidrhost(var.fortigate[i].subnet_cidrs.internal, 4),
      VAR_internal_mask                   = cidrnetmask(var.fortigate[i].subnet_cidrs.internal),
      VAR_internal_port                   = element(var.interface_mapping[0].internal, 0) + 1,
      VAR_internal_name                   = element(var.interface_mapping[0].internal, 1),
      VAR_remote_ip                       = cidrhost(var.fortigate[i].subnet_cidrs.internal, 4),
      VAR_ssh_key                         = chomp(tls_private_key.ssh_key.public_key_openssh),
      VAR_transit_network                 = cidrhost(var.fortigate[i].subnet_cidrs.transit, 0),
      VAR_transit_netmask                 = cidrnetmask(var.fortigate[i].subnet_cidrs.transit),
      VAR_transit_gateway_amazon_side_asn = var.transit_gateway_amazon_side_asn,
      VAR_unicast_hb_peerip               = cidrhost(var.fortigate[i == 0 ? 1 : 0].subnet_cidrs.management, 4),
      VAR_vpc_id                          = aws_vpc.security-vpc.id
    })
  ]
  fortigate_config_hash = sha256(join(",", [for i in range(length(var.fortigate)) : aws_s3_object.fortigate_config[i].etag]))
}
