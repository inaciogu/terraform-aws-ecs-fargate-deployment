data "aws_secretsmanager_secret" "data_source_secrets" {
  for_each = local.containers
  name     = each.value.secret_manager
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = local.containers
  secret_id = data.aws_secretsmanager_secret.data_source_secrets[each.value.name].id
}

data "aws_security_groups" "services" {
  for_each = local.services
  filter {
    name   = "tag:${each.value.network.security_groups_tag.key}"
    values = each.value.network.security_groups_tag.values
  }
}

data "aws_subnets" "services" {
  for_each = local.services
  filter {
    name   = "tag:${each.value.network.subnets_tag.key}"
    values = each.value.network.subnets_tag.values
  }
}
