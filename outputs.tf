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
