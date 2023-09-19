variable "aws_access_key_id" {
  description = "value of AWS_ACCESS_KEY_ID"
  type        = string
}

variable "aws_secret_access_key" {
  description = "value of AWS_SECRET_ACCESS_KEY"
  type        = string
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
      name = string # Name of the service
      task_definition = object({
        family_name = string # Name of the task definition family
        container_definitions = list(object({
          name                = string # Name of the container
          repository_name     = string # Name of ECR repository to used
          dockerfile_location = string # path to the Dockerfile
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
