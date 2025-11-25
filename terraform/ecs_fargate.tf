# CloudWatch log group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_webapp" {
  name              = "/ecs/webserver"
  retention_in_days = 14
}

# ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "hybrid-ecs-cluster"
}

# Task execution role (pull images, push logs)
data "aws_iam_policy_document" "ecs_task_exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#Task runtime role (for app permissions)
data "aws_iam_policy_document" "ecs_task_role_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_assume.json
}

# Service discovery (private DNS)
resource "aws_service_discovery_private_dns_namespace" "svc" {
  name        = "svc.internal"
  description = "Private namespace for ECS services"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "webapp" {
  name = "webapp"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.svc.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}

# ECS task definition
resource "aws_ecs_task_definition" "webserver" {
  family                   = "webserver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "webserver"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_webapp.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "webserver"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

# ECS service 
resource "aws_ecs_service" "webserver" {
  name            = "webserver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webserver.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.private_a.id]
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false
  }

  # Register to Cloud Map
  service_registries {
    registry_arn = aws_service_discovery_service.webapp.arn
  }

  # Link to ALB target group
  load_balancer {
    target_group_arn = aws_lb_target_group.web_tg.arn
    container_name   = "webserver"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_lb_listener.web_listener,
    aws_cloudwatch_log_group.ecs_webapp,
    aws_iam_role_policy_attachment.ecs_exec_attach
  ]
}

# Allow ECS webapp to publish to EventBridge
resource "aws_iam_policy" "ecs_put_events" {
  name        = "ecs-put-events-policy"
  description = "Allow ECS tasks to put events to EventBridge"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["events:PutEvents"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_put_events_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_put_events.arn
}


