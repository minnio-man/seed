# 
# SECURITY GROUPS
# 

resource "aws_security_group" "app_sg" {
  name        = "app_sg_${terraform.workspace}"
  description = "APP Security Group"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = terraform.workspace
  }
}

# 
# APPLICATION LOAD BALANCER
# The cluster load balancer
# 

resource "aws_lb" "app_cluster_load_balancer" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]

  subnets = data.tfe_outputs.services.values.public_subnets

  tags = {
    Environment = terraform.workspace
  }
}

# 
# LOAD BALANCER LISTENER
# The cluster load balancer listener
# 

resource "aws_lb_listener" "app_listener_http" {
  load_balancer_arn = aws_lb.app_cluster_load_balancer.arn
  port              = "80"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_cluster_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.sydney_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 
# DOMAIN A RECORD
# DNS records for routing the domain to the load balancer
# 

resource "aws_route53_record" "www_user_backend" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.app_cluster_load_balancer.dns_name
    zone_id                = aws_lb.app_cluster_load_balancer.zone_id
    evaluate_target_health = false
  }
}
