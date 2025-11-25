# Application Load Balancer (public)
resource "aws_lb" "web_alb" {
  name               = "webserver-alb"
  internal           = false
  load_balancer_type = "application"

  # Must span at least two AZs for ALB
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  security_groups = [aws_security_group.alb_sg.id]
  enable_deletion_protection = false

  tags = {
    Name = "webserver-alb"
  }
}

# Target Group for ECS tasks
resource "aws_lb_target_group" "web_tg" {
  name        = "webserver-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name = "webserver-tg"
  }
}

# ALB Listener (HTTP :80)
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
