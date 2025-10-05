# Resource Import Discovery Module
# Helps discover and prepare existing resources for import into Terraform

# Use account discovery to get list of accounts
module "account_discovery" {
  source = "../account-discovery"
  
  aws_region                   = var.aws_region
  cross_account_role_name      = var.cross_account_role_name
  create_cross_account_roles   = false
  terraform_state_bucket       = var.terraform_state_bucket
  terraform_lock_table         = var.terraform_lock_table
  default_tags                 = var.default_tags
  excluded_account_ids         = var.excluded_account_ids
}

# Data sources to discover existing resources in each account
locals {
  active_accounts = module.account_discovery.active_accounts
  workload_accounts = {
    for id, acc in module.account_discovery.account_environments : id => acc
    if !contains(["master"], acc.account_type) && !contains(var.excluded_account_ids, id)
  }
}

# Discover VPCs in each account
data "aws_vpcs" "existing" {
  for_each = local.workload_accounts
  
  provider = aws.account_${replace(lower(each.value.name), "-", "_")}
}

# Get detailed VPC information
data "aws_vpc" "existing_details" {
  for_each = {
    for combo in flatten([
      for acc_id, acc in local.workload_accounts : [
        for vpc_id in data.aws_vpcs.existing[acc_id].ids : {
          key    = "${acc_id}-${vpc_id}"
          acc_id = acc_id
          vpc_id = vpc_id
          acc    = acc
        }
      ]
    ]) : combo.key => combo
  }
  
  provider = aws.account_${replace(lower(each.value.acc.name), "-", "_")}
  id       = each.value.vpc_id
}

# Discover subnets
data "aws_subnets" "existing" {
  for_each = {
    for combo in flatten([
      for acc_id, acc in local.workload_accounts : [
        for vpc_id in data.aws_vpcs.existing[acc_id].ids : {
          key    = "${acc_id}-${vpc_id}"
          acc_id = acc_id
          vpc_id = vpc_id
          acc    = acc
        }
      ]
    ]) : combo.key => combo
  }
  
  provider = aws.account_${replace(lower(each.value.acc.name), "-", "_")}
  
  filter {
    name   = "vpc-id"
    values = [each.value.vpc_id]
  }
}

# Get detailed subnet information
data "aws_subnet" "existing_details" {
  for_each = {
    for combo in flatten([
      for vpc_key, vpc_data in data.aws_subnets.existing : [
        for subnet_id in vpc_data.ids : {
          key       = "${vpc_key}-${subnet_id}"
          acc_id    = split("-", vpc_key)[0]
          vpc_id    = split("-", vpc_key)[1]
          subnet_id = subnet_id
          acc       = local.workload_accounts[split("-", vpc_key)[0]]
        }
      ]
    ]) : combo.key => combo
  }
  
  provider = aws.account_${replace(lower(each.value.acc.name), "-", "_")}
  id       = each.value.subnet_id
}

# Discover security groups
data "aws_security_groups" "existing" {
  for_each = local.workload_accounts
  
  provider = aws.account_${replace(lower(each.value.name), "-", "_")}
  
  filter {
    name   = "group-name"
    values = ["*"]
  }
}

# Get detailed security group information
data "aws_security_group" "existing_details" {
  for_each = {
    for combo in flatten([
      for acc_id, acc in local.workload_accounts : [
        for sg_id in data.aws_security_groups.existing[acc_id].ids : {
          key   = "${acc_id}-${sg_id}"
          acc_id = acc_id
          sg_id = sg_id
          acc   = acc
        }
      ]
    ]) : combo.key => combo
  }
  
  provider = aws.account_${replace(lower(each.value.acc.name), "-", "_")}
  id       = each.value.sg_id
}

# Discover EC2 instances
data "aws_instances" "existing" {
  for_each = local.workload_accounts
  
  provider = aws.account_${replace(lower(each.value.acc.name), "-", "_")}
  
  filter {
    name   = "instance-state-name"
    values = ["running", "stopped"]
  }
}

# Get detailed EC2 instance information
data "aws_instance" "existing_details" {
  for_each = {
    for combo in flatten([
      for acc_id, acc in local.workload_accounts : [
        for instance_id in data.aws_instances.existing[acc_id].ids : {
          key         = "${acc_id}-${instance_id}"
          acc_id      = acc_id
          instance_id = instance_id
          acc         = acc
        }
      ]
    ]) : combo.key => combo
  }
  
  provider    = aws.account_${replace(lower(each.value.acc.name), "-", "_")}
  instance_id = each.value.instance_id
}

# Discover load balancers
data "aws_lb" "existing" {
  for_each = var.existing_load_balancers # You'll need to provide LB ARNs or names
  
  provider = aws.account_${replace(lower(each.value.account_name), "-", "_")}
  arn      = each.value.arn
}

# Build resource inventory
locals {
  resource_inventory = {
    for acc_id, acc in local.workload_accounts : acc_id => {
      account_name = acc.name
      environment  = acc.environment
      
      vpcs = {
        for vpc_key, vpc in data.aws_vpc.existing_details : vpc.id => {
          id         = vpc.id
          cidr_block = vpc.cidr_block
          name       = try(vpc.tags["Name"], "")
          tags       = vpc.tags
        }
        if startswith(vpc_key, acc_id)
      }
      
      subnets = {
        for subnet_key, subnet in data.aws_subnet.existing_details : subnet.id => {
          id               = subnet.id
          vpc_id           = subnet.vpc_id
          cidr_block       = subnet.cidr_block
          availability_zone = subnet.availability_zone
          name            = try(subnet.tags["Name"], "")
          tags            = subnet.tags
          type            = subnet.map_public_ip_on_launch ? "public" : "private"
        }
        if startswith(subnet_key, acc_id)
      }
      
      security_groups = {
        for sg_key, sg in data.aws_security_group.existing_details : sg.id => {
          id          = sg.id
          name        = sg.name
          description = sg.description
          vpc_id      = sg.vpc_id
          tags        = sg.tags
        }
        if startswith(sg_key, acc_id) && sg.name != "default"
      }
      
      ec2_instances = {
        for instance_key, instance in data.aws_instance.existing_details : instance.id => {
          id            = instance.id
          instance_type = instance.instance_type
          ami           = instance.ami
          subnet_id     = instance.subnet_id
          name          = try(instance.tags["Name"], "")
          tags          = instance.tags
          state         = instance.instance_state
        }
        if startswith(instance_key, acc_id)
      }
      
      resource_counts = {
        vpcs            = length([for k, v in data.aws_vpcs.existing : k if k == acc_id])
        subnets         = length([for k, v in data.aws_subnets.existing : sum([for id in v.ids : 1]) if startswith(k, acc_id)])
        security_groups = length([for k, v in data.aws_security_groups.existing : length(v.ids) if k == acc_id])
        ec2_instances   = length([for k, v in data.aws_instances.existing : length(v.ids) if k == acc_id])
      }
    }
  }
}

# Generate import blocks (Terraform 1.5+)
resource "local_file" "import_blocks" {
  for_each = local.workload_accounts
  
  filename = "${path.root}/import_configs/${each.value.name}_import_blocks.tf"
  
  content = templatefile("${path.module}/templates/import_blocks.tftpl", {
    account     = each.value
    account_id  = each.key
    resources   = local.resource_inventory[each.key]
  })
}

# Generate import commands
resource "local_file" "import_commands" {
  for_each = local.workload_accounts
  
  filename = "${path.root}/import_scripts/${each.value.name}_import_commands.sh"
  
  content = templatefile("${path.module}/templates/import_commands.tftpl", {
    account     = each.value
    account_id  = each.key
    resources   = local.resource_inventory[each.key]
  })
  
  file_permission = "0755"
}

# Generate resource configurations that match existing resources
resource "local_file" "resource_configs" {
  for_each = local.workload_accounts
  
  filename = "${path.root}/import_configs/${each.value.name}_resources.tf"
  
  content = templatefile("${path.module}/templates/resource_configs.tftpl", {
    account     = each.value
    account_id  = each.key
    resources   = local.resource_inventory[each.key]
  })
}

# Generate a comprehensive import plan
resource "local_file" "import_plan" {
  filename = "${path.root}/IMPORT_PLAN.md"
  
  content = templatefile("${path.module}/templates/import_plan.tftpl", {
    accounts   = local.workload_accounts
    inventory  = local.resource_inventory
  })
}

# Outputs
output "resource_inventory" {
  description = "Complete inventory of existing resources across all accounts"
  value       = local.resource_inventory
}

output "import_summary" {
  description = "Summary of resources available for import"
  value = {
    for acc_id, acc in local.workload_accounts : acc.name => {
      account_id = acc_id
      environment = acc.environment
      total_vpcs = local.resource_inventory[acc_id].resource_counts.vpcs
      total_subnets = local.resource_inventory[acc_id].resource_counts.subnets
      total_security_groups = local.resource_inventory[acc_id].resource_counts.security_groups
      total_ec2_instances = local.resource_inventory[acc_id].resource_counts.ec2_instances
    }
  }
}