variable "aws_access_key_id" {
  description = "value of AWS_ACCESS_KEY_ID"
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "value of AWS_SECRET_ACCESS_KEY"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "value of AWS_DEFAULT_REGION"
  type        = string
}

variable "account_id" {
  description = "value of AWS account id"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks of the public subnets"
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks of the private subnets"
  type        = list(string)
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
}

variable "clusters" {
  description = "A list of ecs clusters to create with configurations"
  type = list(object({
    name = string # Name of the cluster
    services = list(object({
      name                      = string # Name of the service
      enable_queue_auto_scaling = bool   # Whether to enable queue auto scaling
      auto_scaling = optional(object({
        min_capacity = number # Minimum number of tasks
        max_capacity = number # Maximum number of tasks
        queue_name   = string # Name of the queue
        steps = list(object({
          lower_bound = number           # Lower bound of the step
          upper_bound = optional(number) # Upper bound of the step
          change      = number           # Desired count to be changed
        }))
      }))
      task_definition = object({
        family_name = string # Name of the task definition family
        container_definitions = list(object({
          name                    = string           # Name of the container
          create_repository_setup = bool             # Whether to create the repository
          repository_name         = string           # Name of ECR repository to be used
          dockerfile_location     = optional(string) # path to the Dockerfile
          portMappings = optional(list(object({
            containerPort = number # Port of the container
            hostPort      = number # Port of the host
            protocol      = string # Protocol of the port
          })))
          environment = optional(list(object({
            name  = string # Name of the environment variable
            value = string # Value of the environment variable
          })))             # Environment variables
          secrets = optional(list(object({
            name      = string # Name of the secret
            valueFrom = string # ARN of the secret
          })))
        }))
        cpu    = number # CPU units
        memory = number # Memory units
      })
      desired_count = number # Desired number of tasks
    }))
  }))
}
