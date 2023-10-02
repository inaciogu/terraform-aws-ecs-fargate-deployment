provider "aws" {
  region     = "us-east-1"
  secret_key = ""
  access_key = ""
}

module "ecs-fargate" {
  source                = "../"
  aws_access_key_id     = ""
  aws_secret_access_key = ""
  aws_region            = ""
  account_id            = ""

  vpc_cidr_block             = "10.0.0.0/16"
  public_subnet_cidr_blocks  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr_blocks = ["10.0.4.0/24", "10.0.5.0/24"]
  security_group_name        = "example-security-group"

  clusters = [{
    name = "example-cluster"
    services = [{
      desired_count = 1
      name          = "example-service"
      task_definition = {
        cpu         = 1024
        memory      = 2048
        family_name = "example-task"
        container_definitions = [
          {
            name                    = "example-container"
            repository_name         = "example-repository"
            create_repository_setup = false
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
