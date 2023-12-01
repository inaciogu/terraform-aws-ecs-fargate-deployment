data "aws_secretsmanager_secret" "data_source_secrets" {
  for_each = local.containers
  name     = each.value.secret_manager
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = local.containers
  secret_id = data.aws_secretsmanager_secret.data_source_secrets[each.value.name].id
}
