# VPC Module Variables - For Each Pattern
# Configuration objects for creating VPC resources dynamically

variable "vpcs" {
  description = "Map of VPC configurations"
  type = map(object({
    cidr_block           = string
    enable_dns_hostnames = optional(bool, true)
    enable_dns_support   = optional(bool, true)
    instance_tenancy     = optional(string, "default")
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "internet_gateways" {
  description = "Map of Internet Gateway configurations"
  type = map(object({
    vpc_key = string
    tags    = optional(map(string), {})
  }))
  default = {}
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    vpc_key                         = string
    cidr_block                      = string
    availability_zone               = string
    map_public_ip_on_launch         = optional(bool, false)
    assign_ipv6_address_on_creation = optional(bool, false)
    tier                           = optional(string, "private") # private, public, database, etc.
    type                           = optional(string, "Subnet")
    tags                           = optional(map(string), {})
  }))
  default = {}
}

variable "elastic_ips" {
  description = "Map of Elastic IP configurations"
  type = map(object({
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "nat_gateways" {
  description = "Map of NAT Gateway configurations"
  type = map(object({
    subnet_key = string
    eip_key    = string
    tags       = optional(map(string), {})
  }))
  default = {}
}

variable "route_tables" {
  description = "Map of route table configurations"
  type = map(object({
    vpc_key = string
    routes = optional(list(object({
      cidr_block                = optional(string)
      ipv6_cidr_block          = optional(string)
      gateway_id               = optional(string)
      gateway_type             = optional(string) # igw, vgw, etc.
      nat_gateway_id           = optional(string)
      vpc_peering_connection_id = optional(string)
      network_interface_id     = optional(string)
      transit_gateway_id       = optional(string)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "route_table_associations" {
  description = "Map of route table association configurations"
  type = map(object({
    subnet_key      = string
    route_table_key = string
  }))
  default = {}
}

variable "vpc_endpoints" {
  description = "Map of VPC endpoint configurations"
  type = map(object({
    vpc_key             = string
    service_name        = string
    vpc_endpoint_type   = optional(string, "Gateway")
    route_table_keys    = optional(list(string))
    subnet_keys         = optional(list(string))
    security_group_ids  = optional(list(string))
    private_dns_enabled = optional(bool, false)
    policy              = optional(string)
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
