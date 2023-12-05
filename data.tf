data "aws_secretsmanager_secret" "data_source_secrets" {
  for_each = local.containers
  name     = each.value.secret_manager
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = local.containers
  secret_id = data.aws_secretsmanager_secret.data_source_secrets[each.value.name].id
}

data "aws_security_groups" "services" {
  for_each = local.networks
  filter {
    name   = "tag:${each.value.security_groups_tag.key}"
    values = each.value.security_groups_tag.values
  }
}

data "aws_subnets" "services" {
  for_each = local.networks
  filter {
    name   = "tag:${each.value.subnets_tag.key}"
    values = each.value.subnets_tag.values
  }
}
