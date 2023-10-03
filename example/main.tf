provider "aws" {
  region = "us-east-1"

  access_key = ""
  secret_key = ""
}

module "ecs-fargate" {
  source     = "../"
  aws_region = "us-east-1"
  account_id = "123456789012"

  vpc_cidr_block             = "10.0.0.0/16"
  public_subnet_cidr_blocks  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr_blocks = ["10.0.4.0/24", "10.0.5.0/24"]
  security_group_name        = "example-security-group"

  clusters = [{
    name = "example-cluster"
    services = [{
      desired_count             = 1
      name                      = "example-service"
      enable_queue_auto_scaling = true
      auto_scaling = {
        min_capacity = 1
        max_capacity = 10
        queue_name   = "example-queue"
        steps = [{
          lower_bound = 1
          upper_bound = 2
          change      = 1
          },
          {
            lower_bound = 2
            upper_bound = 3
            change      = 2
          },
          {
            lower_bound = 3
            upper_bound = 4
            change      = 3
          },
          {
            lower_bound = 4
            change      = 4
          }
        ]
      }
      task_definition = {
        cpu         = 512
        memory      = 1024
        family_name = "example-task"
        container_definitions = [
          {
            name                    = "example-container"
            repository_name         = "example-repository"
            create_repository_setup = true
            dockerfile_location     = "."
            portMappings = [{
              containerPort = 80
              hostPort      = 80
              protocol      = "tcp"
            }]
            environment = [
              {
                name  = "EXAMPLE_ENVIRONMENT_VARIABLE"
                value = "example-value"
              }
            ]
          },
        ]
      }
    }]
  }]
}
