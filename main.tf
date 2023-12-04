resource "aws_ecr_repository" "repository" {
  for_each = local.ecr_repositories

  name = each.value.name

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "null_resource" "build_docker_image" {
  for_each = local.ecr_repositories

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.repository[each.value.name].repository_url}"
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
      AWS_DEFAULT_REGION    = var.aws_region
    }
  }

  provisioner "local-exec" {
    command = "docker build -t ${each.value.name}:latest ${each.value.dockerfile_path}"
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
      AWS_DEFAULT_REGION    = var.aws_region
    }
  }

  provisioner "local-exec" {
    command = "docker tag ${each.value.name}:latest ${aws_ecr_repository.repository[each.value.name].repository_url}:latest"
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
      AWS_DEFAULT_REGION    = var.aws_region
    }
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.repository[each.value.name].repository_url}:latest"
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
      AWS_DEFAULT_REGION    = var.aws_region
    }
  }
}

resource "aws_ecs_task_definition" "task-def" {
  for_each = local.services

  family = each.value.task_definition.family_name
  container_definitions = jsonencode([
    for container in each.value.task_definition.container_definitions : {
      name         = container.name
      image        = "${var.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${container.repository_name}:latest"
      portMappings = container.portMappings
      environment  = container.environment
      secrets      = container.secret_manager != null ? local.secrets[container.name] : container.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${container.name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
    }
  ])

  cpu    = each.value.task_definition.cpu
  memory = each.value.task_definition.memory

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role[each.key].arn

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_ecs_cluster" "cluster" {
  for_each = local.clusters_to_create

  name = each.value.name

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_ecs_service" "ecs_service" {
  for_each = local.services

  name            = each.value.name
  cluster         = "arn:aws:ecs:${var.aws_region}:${var.account_id}:cluster/${each.value.cluster}"
  task_definition = aws_ecs_task_definition.task-def[each.value.name].arn
  desired_count   = each.value.desired_count

  force_new_deployment = true
  launch_type          = "FARGATE"
  network_configuration {
    security_groups  = each.value.network == null ? [aws_security_group.ecs[0].id] : each.value.network.security_groups
    subnets          = each.value.network == null ? aws_subnet.private_subnet.*.id : each.value.network.subnets
    assign_public_ip = true
  }

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  for_each = local.services_to_scale

  max_capacity       = each.value.auto_scaling.max_capacity
  min_capacity       = each.value.auto_scaling.min_capacity
  resource_id        = "service/${each.value.cluster}/${each.key}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_appautoscaling_policy" "ecs_scale_up_policy" {
  for_each = local.services_to_scale

  name        = "${each.key}_sqs_scale_up_policy"
  policy_type = "StepScaling"
  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    metric_aggregation_type = "Average"

    dynamic "step_adjustment" {
      for_each = each.value.auto_scaling.steps

      content {
        metric_interval_lower_bound = step_adjustment.value.lower_bound
        metric_interval_upper_bound = step_adjustment.value.upper_bound
        scaling_adjustment          = step_adjustment.value.change
      }
    }
  }

  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace
}

resource "aws_cloudwatch_metric_alarm" "sqs_scale_out" {
  for_each = local.services_to_scale

  alarm_name = "${each.key}-SQS-ScaleOut"

  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ApproximateNumberOfMessagesVisible"
  namespace                 = "AWS/SQS"
  period                    = "60"
  threshold                 = "1"
  statistic                 = "Sum"
  alarm_description         = "scale up ${each.key} service"
  insufficient_data_actions = []
  alarm_actions = [
    aws_appautoscaling_policy.ecs_scale_up_policy[each.key].arn
  ]

  dimensions = {
    QueueName = each.value.auto_scaling.queue_name
  }

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}
