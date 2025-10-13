# VPC Module
# Creates VPC resources based on configuration object using for_each pattern
# This design allows for flexible resource creation and easy importing of existing resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPCs
resource "aws_vpc" "this" {
  for_each = var.vpcs

  cidr_block           = each.value.cidr_block
  enable_dns_hostnames = lookup(each.value, "enable_dns_hostnames", true)
  enable_dns_support   = lookup(each.value, "enable_dns_support", true)
  instance_tenancy     = lookup(each.value, "instance_tenancy", "default")

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "VPC"
    }
  )
}

# Internet Gateways
resource "aws_internet_gateway" "this" {
  for_each = var.internet_gateways

  vpc_id = aws_vpc.this[each.value.vpc_key].id

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "InternetGateway"
    }
  )
}

# Subnets
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                          = aws_vpc.this[each.value.vpc_key].id
  cidr_block                      = each.value.cidr_block
  availability_zone               = each.value.availability_zone
  map_public_ip_on_launch         = lookup(each.value, "map_public_ip_on_launch", false)
  assign_ipv6_address_on_creation = lookup(each.value, "assign_ipv6_address_on_creation", false)

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = lookup(each.value, "type", "Subnet")
      Tier = lookup(each.value, "tier", "private")
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "this" {
  for_each = var.elastic_ips

  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "EIP"
    }
  )
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  for_each = var.nat_gateways

  allocation_id = aws_eip.this[each.value.eip_key].id
  subnet_id     = aws_subnet.this[each.value.subnet_key].id
  depends_on    = [aws_internet_gateway.this]

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "NATGateway"
    }
  )
}

# Route Tables
resource "aws_route_table" "this" {
  for_each = var.route_tables

  vpc_id = aws_vpc.this[each.value.vpc_key].id

  # Dynamic routes
  dynamic "route" {
    for_each = lookup(each.value, "routes", [])
    content {
      cidr_block                = lookup(route.value, "cidr_block", null)
      ipv6_cidr_block          = lookup(route.value, "ipv6_cidr_block", null)
      gateway_id               = lookup(route.value, "gateway_id", null) != null ? (lookup(route.value, "gateway_type", "") == "igw" ? aws_internet_gateway.this[route.value.gateway_id].id : route.value.gateway_id) : null
      nat_gateway_id           = lookup(route.value, "nat_gateway_id", null) != null ? aws_nat_gateway.this[route.value.nat_gateway_id].id : null
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
      network_interface_id     = lookup(route.value, "network_interface_id", null)
      transit_gateway_id       = lookup(route.value, "transit_gateway_id", null)
    }
  }

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "RouteTable"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "this" {
  for_each = var.route_table_associations

  subnet_id      = aws_subnet.this[each.value.subnet_key].id
  route_table_id = aws_route_table.this[each.value.route_table_key].id
}

# VPC Endpoints
resource "aws_vpc_endpoint" "this" {
  for_each = var.vpc_endpoints

  vpc_id              = aws_vpc.this[each.value.vpc_key].id
  service_name        = each.value.service_name
  vpc_endpoint_type   = lookup(each.value, "vpc_endpoint_type", "Gateway")
  route_table_ids     = lookup(each.value, "route_table_keys", null) != null ? [for rt_key in each.value.route_table_keys : aws_route_table.this[rt_key].id] : null
  subnet_ids          = lookup(each.value, "subnet_keys", null) != null ? [for subnet_key in each.value.subnet_keys : aws_subnet.this[subnet_key].id] : null
  security_group_ids  = lookup(each.value, "security_group_ids", null)
  private_dns_enabled = lookup(each.value, "private_dns_enabled", false)
  policy              = lookup(each.value, "policy", null)

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "VPCEndpoint"
    }
  )
}
