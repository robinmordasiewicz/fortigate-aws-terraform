variable "company" {
  type        = string
  description = "Company name - used as a resource tag"
  default     = "ACME Corp"
}

variable "createdby" {
  type        = string
  description = "Created by - used as a resource tag"
  default     = "Terraform"
}

variable "project" {
  type        = string
  description = "Project - used as a resource tag"
  default     = "fortigate-ngfw-aws"
}

variable "environment" {
  type        = string
  description = "Environment - used as a resource tag"
  default     = "sandbox"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "vpc_name" {
  type        = string
  description = "VPC name"
  default     = "security"
}

variable "vpc_cidr" {
  type        = string
  description = "Base CIDR Block for VPC"
  default     = "10.0.0.0/24"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid IPv4 CIDR notation, e.g., 10.0.0.0/16."
  }
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in VPC"
  default     = true
}

variable "fortigate" {
  type = list(object({
    hostname_prefix    = string
    subnet_cidrs       = map(string)
    bgp_asn            = number
    inside_cidr_blocks = list(string)
    priority           = number
  }))
  default = [
    {
      hostname_prefix = "firewall"
      subnet_cidrs = {
        external   = "10.0.0.0/28"
        internal   = "10.0.0.16/28"
        management = "10.0.0.48/28"
        transit    = "1.0.0.0/8"
      }
      bgp_asn            = 64513
      inside_cidr_blocks = ["169.254.120.0/29"]
      priority           = 200
    },
    {
      hostname_prefix = "firewall"
      subnet_cidrs = {
        external   = "10.0.0.64/28"
        internal   = "10.0.0.80/28"
        management = "10.0.0.112/28"
        transit    = "1.0.0.0/8"
      }
      bgp_asn            = 64514
      inside_cidr_blocks = ["169.254.102.0/29"]
      priority           = 150
    }
  ]
}

variable "arch" {
  type    = string
  default = "x86_64"
  validation {
    condition     = var.arch == "x86_64" || var.arch == "arm64"
    error_message = "The instance_architecture must be either 'x86_64' or 'arm64'."
  }
}

variable "size" {
  type    = string
  default = "c6i.xlarge"
}

variable "release" {
  type        = string
  default     = "7.6.0"
  description = "Fortigate Version"
}

variable "license_type" {
  type    = string
  default = "byol"
  validation {
    condition     = var.license_type == "byol" || var.license_type == "payg"
    error_message = "The license_type must be either 'byol' or 'payg'."
  }
}

variable "fortigate_bootstrap" {
  type        = string
  description = "Path to fortigate template config"
  default     = "cloud-init/fortigate.conf"
}

variable "admin_sport" {
  description = "Management port for admin UI"
  type        = string
  default     = "443"
}

variable "fortigate_license" {
  description = "List of paths to the license files for Fortigate instances"
  type        = list(string)
  default     = ["licenses/fortigate-A.lic", "licenses/fortigate-B.lic"]
}

variable "transit_gateway_amazon_side_asn" {
  type        = number
  description = "ASN Number on the AWS transit gateway"
  default     = 64512
}

variable "subnet_types" {
  type    = list(string)
  default = ["external", "internal", "management"]
}

variable "interface_mapping" {
  type = list(object({
    external   = list(string)
    internal   = list(string)
    management = list(string)
  }))
  default = [
    {
      external   = ["0", "public"]
      internal   = ["1", "private"]
      management = ["2", "ha"]
    }
  ]
}
