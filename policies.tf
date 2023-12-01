resource "aws_iam_role" "ecs_execution_role" {
  for_each = local.services

  name = "${each.value.task_definition.family_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  for_each = local.services

  name = "${each.value.task_definition.family_name}-execution-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ],
        "Resource" : [
          for container in each.value.task_definition.container_definitions : "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${container.repository_name}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          for container in each.value.task_definition.container_definitions : "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/ecs/${container.name}:*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : [
          for container in each.value.task_definition.container_definitions : container.secret_manager != null ? data.aws_secretsmanager_secret.data_source_secrets[container.name].arn : "*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  for_each = local.services

  role       = aws_iam_role.ecs_execution_role[each.key].name
  policy_arn = aws_iam_policy.ecs_task_execution_policy[each.key].arn
}
