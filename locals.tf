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
        network                    = service.network
      }]
    ]
  ])


  containers_list = flatten([
    for service in local.service_list : [
      for container in service.task_definition.container_definitions : [
        {
          name           = container.name
          secret_manager = container.secret_manager
        }
      ] if container.secret_manager != null
    ]
  ])

  containers = {
    for container in local.containers_list : container.name => container
  }

  secrets = {
    for container in local.containers : container.name => [
      for key, value in jsondecode(data.aws_secretsmanager_secret_version.secrets[container.name].secret_string) : {
        name      = key
        valueFrom = "${data.aws_secretsmanager_secret.data_source_secrets[container.name].arn}:${key}::"
      }
    ] if container.secret_manager != null
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

  networks = {
    for service in local.service_list : service.name => service.network if service.network != null
  }
}
