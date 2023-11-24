locals {
  repositories_list = flatten([
    for cluster in var.clusters : [
      for service in cluster.services : [
        for container in service.task_definition.container_definitions : [
          {
            name                    = container.repository_name
            dockerfile_path         = container.dockerfile_location
            container_name          = container.name
            create_repository_setup = container.create_repository_setup
          }
        ] if container.create_repository_setup
      ]
    ]
  ])

  service_list = flatten([
    for cluster in var.clusters : [
      for service in cluster.services : [{
        name                       = service.name
        task_definition            = service.task_definition
        cluster                    = cluster.name
        desired_count              = service.desired_count
        enable_queue_auto_scalling = service.enable_queue_auto_scaling == true
        auto_scaling               = service.auto_scaling
      }]
    ]
  ])

  containers_list = flatten([
    for service in local.service_list : [
      for container in service.task_definition.container_definitions : [
        {
          name       = container.name
          secret_arn = container.secret_arn
        }
      ] if container.secret_arn != null
    ]
  ])

  containers = {
    for container in local.containers_list : container.name => container
  }

  secrets = {
    for container in local.containers : container.name => [
      for key, value in jsondecode(data.aws_secretsmanager_secret_version.secrets[container.name].secret_string) : {
        name      = key
        valueFrom = "${container.secret_arn}:${key}::"
      }
    ] if container.secret_arn != null
  }

  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }

  clusters_to_create = {
    for cluster in local.clusters : cluster.name => cluster if cluster.create_cluster == true
  }

  services = {
    for service in local.service_list : service.name => service
  }

  services_to_scale = {
    for service in local.service_list : service.name => service if service.enable_queue_auto_scalling
  }

  ecr_repositories = {
    for repository in local.repositories_list : repository.name => repository
  }
}

resource "aws_ecr_repository" "repository" {
  for_each = local.ecr_repositories

  name = each.value.name
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

data "aws_secretsmanager_secret_version" "secrets" {
  for_each = local.containers

  secret_id = each.value.secret_arn
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
      secrets      = container.secret_arn != null ? local.secrets[container.name] : container.secrets
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
}

resource "aws_ecs_cluster" "cluster" {
  for_each = local.clusters_to_create

  name = each.value.name
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
    security_groups  = [aws_security_group.ecs.id]
    subnets          = aws_subnet.private_subnet.*.id
    assign_public_ip = true
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  for_each = local.services_to_scale

  max_capacity       = each.value.auto_scaling.max_capacity
  min_capacity       = each.value.auto_scaling.min_capacity
  resource_id        = "service/${each.value.cluster}/${each.key}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
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
}
