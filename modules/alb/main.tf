# Application Load Balancer module

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_http2                     = var.enable_http2

  # Access logs
  dynamic "access_logs" {
    for_each = var.access_logs_enabled ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = var.access_logs_enabled
    }
  }

  tags = var.tags
}

# Target Groups
resource "aws_lb_target_group" "main" {
  for_each = var.target_groups

  name     = each.key
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  # Health check configuration
  health_check {
    enabled             = lookup(each.value.health_check, "enabled", true)
    healthy_threshold   = lookup(each.value.health_check, "healthy_threshold", 2)
    interval            = lookup(each.value.health_check, "interval", 30)
    matcher             = lookup(each.value.health_check, "matcher", "200")
    path                = lookup(each.value.health_check, "path", "/")
    port                = lookup(each.value.health_check, "port", "traffic-port")
    protocol            = lookup(each.value.health_check, "protocol", each.value.protocol)
    timeout             = lookup(each.value.health_check, "timeout", 5)
    unhealthy_threshold = lookup(each.value.health_check, "unhealthy_threshold", 2)
  }

  # Target type
  target_type = lookup(each.value, "target_type", "instance")

  # Stickiness
  dynamic "stickiness" {
    for_each = lookup(each.value, "stickiness", null) != null ? [1] : []
    content {
      type            = each.value.stickiness.type
      cookie_duration = lookup(each.value.stickiness, "cookie_duration", 86400)
      enabled         = lookup(each.value.stickiness, "enabled", true)
    }
  }

  tags = merge(var.tags, {
    Name = each.key
  })
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  count = var.create_http_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[var.default_target_group].arn
  }

  tags = var.tags
}

# Listener Rules
resource "aws_lb_listener_rule" "rules" {
  for_each = var.listener_rules

  listener_arn = var.certificate_arn != null ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  priority     = each.value.priority

  action {
    type             = each.value.action.type
    target_group_arn = lookup(each.value.action, "target_group_arn", aws_lb_target_group.main[each.value.action.target_group_key].arn)
  }

  dynamic "condition" {
    for_each = lookup(each.value, "conditions", [])
    content {
      dynamic "path_pattern" {
        for_each = lookup(condition.value, "path_pattern", null) != null ? [condition.value.path_pattern] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = lookup(condition.value, "host_header", null) != null ? [condition.value.host_header] : []
        content {
          values = host_header.value.values
        }
      }
    }
  }

  tags = var.tags
}

# Route53 Alias Record
resource "aws_route53_record" "main" {
  count = var.create_route53_record ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.route53_record_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  for_each = var.create_cloudwatch_alarms ? var.target_groups : {}

  alarm_name          = "${var.name}-${each.key}-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.target_response_time_threshold
  alarm_description   = "This metric monitors target response time"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.main[each.key].arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  for_each = var.create_cloudwatch_alarms ? var.target_groups : {}

  alarm_name          = "${var.name}-${each.key}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.main[each.key].arn_suffix
  }

  tags = var.tags
}