locals {
  repositories_list = flatten([
    for cluster in var.clusters : [
      for service in cluster.services : [
        for container in service.task_definition.container_definitions : [
          {
            name            = container.repository_name
            dockerfile_path = container.dockerfile_location
            container_name  = container.name
          }
        ]
      ]
    ]
  ])

  service_list = flatten([
    for cluster in var.clusters : [
      for service in cluster.services : [{
        name            = service.name
        task_definition = service.task_definition
        cluster         = cluster.name
        desired_count   = service.desired_count
      }]
    ]
  ])

  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }

  services = {
    for service in local.service_list : service.name => service
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

resource "aws_ecs_task_definition" "task-def" {
  for_each = local.services

  family = each.value.task_definition.family_name
  container_definitions = jsonencode([
    for container in each.value.task_definition.container_definitions : {
      name         = container.name
      image        = "${aws_ecr_repository.repository[container.repository_name].repository_url}:latest"
      portMappings = container.portMappings
      environment  = container.environment
      secrets      = container.secrets
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
  for_each = local.clusters

  name = each.value.name
}

resource "aws_ecs_service" "ecs_service" {
  for_each = local.services

  name            = each.value.name
  cluster         = aws_ecs_cluster.cluster[each.value.cluster].id
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
