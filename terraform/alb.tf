#############################
# Application Load Balancer #
#############################

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/S from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Allow the ALB to reach nodeports on the worker nodes
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = var.eks_nodeport
  to_port                  = var.eks_nodeport
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "ALB to EKS nodeports"
}

resource "aws_lb" "public_alb" {
  name               = "eks-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "eks-public-alb"
  }
}

# Target group points at the worker nodes on the NodePort you expose from Kubernetes
resource "aws_lb_target_group" "eks_nodes" {
  name        = "eks-nodes"
  port        = var.eks_nodeport
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Attach the managed node group's Auto Scaling Group to the target group
resource "aws_autoscaling_attachment" "nodes_to_alb" {
  autoscaling_group_name = aws_eks_node_group.default.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.eks_nodes.arn
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_nodes.arn
  }
}
