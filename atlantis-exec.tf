# ---------------------------------------------------------------------------
# Roles de execução que o Atlantis assume, uma por "stack".
#
# A task role do Atlantis em si quase não tem permissão: ela só lê/grava state
# e assume estas roles. Cada stack recebe só o que precisa — um erro no dev
# não consegue tocar o groundwork, e vice-versa.
#
# Confiança por aws:PrincipalArn (e não pelo ARN no principal) porque a task
# role é criada depois, no repo atlantis, e o IAM valida principals na criação.
# ---------------------------------------------------------------------------
locals {
  stacks = {
    groundwork = {
      gerenciadas = ["arn:aws:iam::aws:policy/AmazonVPCFullAccess"]
      prefixo_s3  = "tep-shared-"
      extras = [
        "budgets:*",
        "s3:GetAccountPublicAccessBlock",
        "s3:PutAccountPublicAccessBlock",
        "ec2:EnableEbsEncryptionByDefault",
        "ec2:DisableEbsEncryptionByDefault",
        "ec2:GetEbsEncryptionByDefault",
      ]
    }
    dev = {
      gerenciadas = []
      prefixo_s3  = "tep-dev-"
      extras      = []
    }
    prod = {
      gerenciadas = []
      prefixo_s3  = "tep-prod-"
      extras      = []
    }
  }

  stacks_gerenciadas = merge([
    for stack, cfg in local.stacks : { for p in cfg.gerenciadas : "${stack}|${p}" => { stack = stack, politica = p } }
  ]...)
}

data "aws_iam_policy_document" "confia_atlantis" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.conta}:root"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${local.conta}:role/${var.nome_role_atlantis}"]
    }
  }
}

resource "aws_iam_role" "exec" {
  for_each = local.stacks

  name                 = "terraform-exec-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.confia_atlantis.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "exec" {
  for_each = local.stacks

  statement {
    sid       = "BucketsDaStack"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${each.value.prefixo_s3}*", "arn:aws:s3:::${each.value.prefixo_s3}*/*"]
  }

  dynamic "statement" {
    for_each = length(each.value.extras) > 0 ? [1] : []

    content {
      sid       = "Extras"
      actions   = each.value.extras
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "exec" {
  for_each = local.stacks

  name   = "permissoes-da-stack"
  role   = aws_iam_role.exec[each.key].id
  policy = data.aws_iam_policy_document.exec[each.key].json
}

resource "aws_iam_role_policy_attachment" "exec" {
  for_each = local.stacks_gerenciadas

  role       = aws_iam_role.exec[each.value.stack].name
  policy_arn = each.value.politica
}
