# ECS Fargate terraform module

This module creates the full ECS Fargate setup, including the push of the docker image to ECR using your Dockerfile.

## Usage

```hcl
module "ecs-fargate" {
  source                = "github.com/inaciogu/terraform-aws-ecs-fargate-deployment"
  aws_access_key_id     = "test"
  aws_secret_access_key = "test"
  aws_region            = "us-east-1"
  account_id            = "00000000000"

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

### Secrets Manager integration

If you want to use secrets from Secrets Manager, you can use the **secret_manager** property in the container_definitions. The values stored in the secret will be set as secrets inside the container, and will be available as environment variables.

```hcl
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
    secret_manager = "example-secret-name"
  },
]
```

### Network

You can use existing subnets and security groups by setting the `network` object inside the `service` or create the vpc configuration from scratch using the variables `vpc_cidr_block`, `public_subnet_cidr_blocks`, `private_subnet_cidr_blocks` and `security_group_name`.

Existing network setup:

```hcl
services = [{
  name = "example-service"
  network = {
    subnets_tags = {
			"Name" = "example-subnet"
		}
    security_groups_tags = {
			"Name" = "example-security-group"
		}
  }
}]
```

New network setup:

```hcl
vpc_cidr_block             = "10.0.0.0/16"
public_subnet_cidr_blocks  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]
security_group_name        = "example-security-group"
```
**Note:** Currently, the module supports just one vpc creation thats why the vpc variables are not inside the `service` object.
