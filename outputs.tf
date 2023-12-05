output "clusters" {
  value = local.clusters
}

output "repositories" {
  value = local.ecr_repositories
}

output "services" {
  value = local.services
}

output "secrets_data_source" {
  value = data.aws_secretsmanager_secret_version.secrets
}

output "security_groups" {
  value = data.aws_security_groups.services
}

output "subnets" {
  value = data.aws_subnets.services
}
