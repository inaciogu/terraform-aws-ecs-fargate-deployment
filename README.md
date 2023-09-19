# ECS Fargate terraform module

This module creates the full ECS Fargate setup, including the push of the docker image to ECR using your Dockerfile.

## Usage

```hcl
module "ecs-fargate" {
  source                = "github.com/inaciogu/ecs-fargate-deployment"
  aws_access_key_id     = "test"
  aws_secret_access_key = "test"
  aws_region            = "us-east-1"
  account_id            = "00000000000"

  vpc_cidr_block             = "10.0.0.0/16"
  public_subnet_cidr_blocks  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr_blocks = ["10.0.4.0/24", "10.0.5.0/24"]

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
            name                = "example-container"
            repository_name     = "example-repository"
            dockerfile_location = "."
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
```

