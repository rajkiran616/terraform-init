# Security Groups module for multi-account infrastructure

# Web tier security group
resource "aws_security_group" "web" {
  count = var.create_web_sg ? 1 : 0

  name_prefix = "${var.name_prefix}-web-"
  vpc_id      = var.vpc_id
  description = "Security group for web servers"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.web_ingress_cidrs
    description = "HTTP"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.web_ingress_cidrs
    description = "HTTPS"
  }

  # SSH from bastion
  dynamic "ingress" {
    for_each = var.bastion_sg_id != null ? [1] : []
    content {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_id = var.bastion_sg_id
      description              = "SSH from bastion"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-web-sg"
    Type = "Web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application tier security group
resource "aws_security_group" "app" {
  count = var.create_app_sg ? 1 : 0

  name_prefix = "${var.name_prefix}-app-"
  vpc_id      = var.vpc_id
  description = "Security group for application servers"

  # Application port from web tier
  dynamic "ingress" {
    for_each = var.create_web_sg ? [1] : []
    content {
      from_port                = var.app_port
      to_port                  = var.app_port
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.web[0].id
      description              = "Application port from web tier"
    }
  }

  # SSH from bastion
  dynamic "ingress" {
    for_each = var.bastion_sg_id != null ? [1] : []
    content {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_id = var.bastion_sg_id
      description              = "SSH from bastion"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-sg"
    Type = "Application"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Database tier security group
resource "aws_security_group" "database" {
  count = var.create_database_sg ? 1 : 0

  name_prefix = "${var.name_prefix}-database-"
  vpc_id      = var.vpc_id
  description = "Security group for database servers"

  # MySQL/Aurora port from app tier
  dynamic "ingress" {
    for_each = var.create_app_sg ? [1] : []
    content {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.app[0].id
      description              = "MySQL from application tier"
    }
  }

  # PostgreSQL port from app tier
  dynamic "ingress" {
    for_each = var.create_app_sg ? [1] : []
    content {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.app[0].id
      description              = "PostgreSQL from application tier"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-sg"
    Type = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Bastion security group
resource "aws_security_group" "bastion" {
  count = var.create_bastion_sg ? 1 : 0

  name_prefix = "${var.name_prefix}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion hosts"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_ingress_cidrs
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
    Type = "Bastion"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Load balancer security group
resource "aws_security_group" "alb" {
  count = var.create_alb_sg ? 1 : 0

  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
    description = "HTTP"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
    Type = "LoadBalancer"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EFS security group
resource "aws_security_group" "efs" {
  count = var.create_efs_sg ? 1 : 0

  name_prefix = "${var.name_prefix}-efs-"
  vpc_id      = var.vpc_id
  description = "Security group for EFS"

  # NFS from app tier
  dynamic "ingress" {
    for_each = var.create_app_sg ? [1] : []
    content {
      from_port                = 2049
      to_port                  = 2049
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.app[0].id
      description              = "NFS from application tier"
    }
  }

  # NFS from web tier
  dynamic "ingress" {
    for_each = var.create_web_sg ? [1] : []
    content {
      from_port                = 2049
      to_port                  = 2049
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.web[0].id
      description              = "NFS from web tier"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-efs-sg"
    Type = "EFS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Custom security groups from variable
resource "aws_security_group" "custom" {
  for_each = var.custom_security_groups

  name_prefix = "${var.name_prefix}-${each.key}-"
  vpc_id      = var.vpc_id
  description = each.value.description

  dynamic "ingress" {
    for_each = each.value.ingress_rules
    content {
      from_port                = ingress.value.from_port
      to_port                  = ingress.value.to_port
      protocol                 = ingress.value.protocol
      cidr_blocks              = lookup(ingress.value, "cidr_blocks", null)
      source_security_group_id = lookup(ingress.value, "source_security_group_id", null)
      description              = lookup(ingress.value, "description", "")
    }
  }

  dynamic "egress" {
    for_each = each.value.egress_rules
    content {
      from_port                = egress.value.from_port
      to_port                  = egress.value.to_port
      protocol                 = egress.value.protocol
      cidr_blocks              = lookup(egress.value, "cidr_blocks", null)
      source_security_group_id = lookup(egress.value, "destination_security_group_id", null)
      description              = lookup(egress.value, "description", "")
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name = "${var.name_prefix}-${each.key}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}