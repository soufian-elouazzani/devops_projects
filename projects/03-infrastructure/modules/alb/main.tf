resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_lb_target_group" "color" {
  for_each = toset(["blue", "green"])

  name                 = "${var.name}-${each.key}"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    protocol            = "HTTP"
  }

  tags = {
    Name  = "${var.name}-${each.key}"
    Color = each.key
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.color["blue"].arn
        weight = var.blue_weight
      }

      target_group {
        arn    = aws_lb_target_group.color["green"].arn
        weight = var.green_weight
      }

      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }
}
