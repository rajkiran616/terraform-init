output "web_sg_id" {
  description = "ID of the web security group"
  value       = var.create_web_sg ? aws_security_group.web[0].id : null
}

output "web_sg_arn" {
  description = "ARN of the web security group"
  value       = var.create_web_sg ? aws_security_group.web[0].arn : null
}

output "app_sg_id" {
  description = "ID of the application security group"
  value       = var.create_app_sg ? aws_security_group.app[0].id : null
}

output "app_sg_arn" {
  description = "ARN of the application security group"
  value       = var.create_app_sg ? aws_security_group.app[0].arn : null
}

output "database_sg_id" {
  description = "ID of the database security group"
  value       = var.create_database_sg ? aws_security_group.database[0].id : null
}

output "database_sg_arn" {
  description = "ARN of the database security group"
  value       = var.create_database_sg ? aws_security_group.database[0].arn : null
}

output "bastion_sg_id" {
  description = "ID of the bastion security group"
  value       = var.create_bastion_sg ? aws_security_group.bastion[0].id : null
}

output "bastion_sg_arn" {
  description = "ARN of the bastion security group"
  value       = var.create_bastion_sg ? aws_security_group.bastion[0].arn : null
}

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = var.create_alb_sg ? aws_security_group.alb[0].id : null
}

output "alb_sg_arn" {
  description = "ARN of the ALB security group"
  value       = var.create_alb_sg ? aws_security_group.alb[0].arn : null
}

output "efs_sg_id" {
  description = "ID of the EFS security group"
  value       = var.create_efs_sg ? aws_security_group.efs[0].id : null
}

output "efs_sg_arn" {
  description = "ARN of the EFS security group"
  value       = var.create_efs_sg ? aws_security_group.efs[0].arn : null
}

output "custom_security_groups" {
  description = "Map of custom security groups"
  value = {
    for k, v in aws_security_group.custom : k => {
      id   = v.id
      arn  = v.arn
      name = v.name
    }
  }
}

output "all_security_groups" {
  description = "Map of all security groups created"
  value = merge(
    var.create_web_sg ? { web = { id = aws_security_group.web[0].id, arn = aws_security_group.web[0].arn } } : {},
    var.create_app_sg ? { app = { id = aws_security_group.app[0].id, arn = aws_security_group.app[0].arn } } : {},
    var.create_database_sg ? { database = { id = aws_security_group.database[0].id, arn = aws_security_group.database[0].arn } } : {},
    var.create_bastion_sg ? { bastion = { id = aws_security_group.bastion[0].id, arn = aws_security_group.bastion[0].arn } } : {},
    var.create_alb_sg ? { alb = { id = aws_security_group.alb[0].id, arn = aws_security_group.alb[0].arn } } : {},
    var.create_efs_sg ? { efs = { id = aws_security_group.efs[0].id, arn = aws_security_group.efs[0].arn } } : {},
    {
      for k, v in aws_security_group.custom : k => {
        id  = v.id
        arn = v.arn
      }
    }
  )
}