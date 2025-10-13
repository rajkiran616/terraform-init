# VPC Module Outputs - For Each Pattern
# Returns maps of all created resources for easy reference

output "vpcs" {
  description = "Map of VPC resources"
  value = {
    for k, v in aws_vpc.this : k => {
      id                     = v.id
      arn                    = v.arn
      cidr_block            = v.cidr_block
      default_security_group_id = v.default_security_group_id
      default_network_acl_id    = v.default_network_acl_id
      main_route_table_id       = v.main_route_table_id
      owner_id              = v.owner_id
      tags                  = v.tags_all
    }
  }
}

output "internet_gateways" {
  description = "Map of Internet Gateway resources"
  value = {
    for k, v in aws_internet_gateway.this : k => {
      id      = v.id
      arn     = v.arn
      vpc_id  = v.vpc_id
      tags    = v.tags_all
    }
  }
}

output "subnets" {
  description = "Map of subnet resources"
  value = {
    for k, v in aws_subnet.this : k => {
      id                = v.id
      arn               = v.arn
      vpc_id            = v.vpc_id
      cidr_block        = v.cidr_block
      availability_zone = v.availability_zone
      availability_zone_id = v.availability_zone_id
      map_public_ip_on_launch = v.map_public_ip_on_launch
      tags              = v.tags_all
    }
  }
}

output "elastic_ips" {
  description = "Map of Elastic IP resources"
  value = {
    for k, v in aws_eip.this : k => {
      id               = v.id
      public_ip        = v.public_ip
      public_dns       = v.public_dns
      allocation_id    = v.allocation_id
      association_id   = v.association_id
      domain          = v.domain
      tags            = v.tags_all
    }
  }
}

output "nat_gateways" {
  description = "Map of NAT Gateway resources"
  value = {
    for k, v in aws_nat_gateway.this : k => {
      id            = v.id
      allocation_id = v.allocation_id
      subnet_id     = v.subnet_id
      public_ip     = v.public_ip
      private_ip    = v.private_ip
      tags          = v.tags_all
    }
  }
}

output "route_tables" {
  description = "Map of route table resources"
  value = {
    for k, v in aws_route_table.this : k => {
      id     = v.id
      arn    = v.arn
      vpc_id = v.vpc_id
      routes = v.route
      tags   = v.tags_all
    }
  }
}

output "route_table_associations" {
  description = "Map of route table association resources"
  value = {
    for k, v in aws_route_table_association.this : k => {
      id             = v.id
      subnet_id      = v.subnet_id
      route_table_id = v.route_table_id
    }
  }
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint resources"
  value = {
    for k, v in aws_vpc_endpoint.this : k => {
      id                = v.id
      arn               = v.arn
      vpc_id            = v.vpc_id
      service_name      = v.service_name
      vpc_endpoint_type = v.vpc_endpoint_type
      state             = v.state
      dns_entry         = v.dns_entry
      network_interface_ids = v.network_interface_ids
      tags              = v.tags_all
    }
  }
}

# Convenience outputs for common use cases
output "vpc_ids" {
  description = "Map of VPC names to IDs"
  value       = { for k, v in aws_vpc.this : k => v.id }
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "public_subnet_ids" {
  description = "Map of public subnet names to IDs"
  value = {
    for k, v in aws_subnet.this : k => v.id
    if lookup(var.subnets[k], "tier", "private") == "public"
  }
}

output "private_subnet_ids" {
  description = "Map of private subnet names to IDs"
  value = {
    for k, v in aws_subnet.this : k => v.id
    if lookup(var.subnets[k], "tier", "private") == "private"
  }
}

output "database_subnet_ids" {
  description = "Map of database subnet names to IDs"
  value = {
    for k, v in aws_subnet.this : k => v.id
    if lookup(var.subnets[k], "tier", "private") == "database"
  }
}

output "availability_zones" {
  description = "List of available availability zones"
  value       = data.aws_availability_zones.available.names
}
