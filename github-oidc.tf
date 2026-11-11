# ---------------------------------------------------------------------------
# GitHub Actions -> AWS sem chave estática (OIDC).
# Usado por: deploy do próprio Atlantis e detecção de drift.
# O Atlantis NÃO usa OIDC: ele roda no ECS e usa a task role.
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  count = var.criar_provider_oidc ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.criar_provider_oidc ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.criar_provider_oidc ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # Cada role define QUEM (repo + contexto do job) pode assumi-la.
  # O sub pode vir com os IDs numéricos (repo:org@123/repo@456:...) se a org
  # optar por esse formato, por isso as duas formas.
  roles_github = {
    "github-atlantis-plan" = {
      subs     = ["repo:${var.github_org}/atlantis:pull_request"]
      politica = "arn:aws:iam::aws:policy/ReadOnlyAccess"
      state    = { prefixos = ["atlantis/"], escrita = true }
    }
    # Só um job com `environment: producao` chega aqui.
    "github-atlantis-apply" = {
      subs     = ["repo:${var.github_org}/atlantis:environment:producao"]
      politica = "arn:aws:iam::aws:policy/AdministratorAccess"
      state    = { prefixos = ["atlantis/"], escrita = true }
    }
    "github-drift" = {
      subs = [
        "repo:${var.github_org}/infra-live:ref:refs/heads/main",
        "repo:${var.github_org}/groundwork:ref:refs/heads/main",
      ]
      politica = "arn:aws:iam::aws:policy/ReadOnlyAccess"
      state    = { prefixos = ["infra-live/", "groundwork/"], escrita = false }
    }
  }
}

data "aws_iam_policy_document" "confia_github" {
  for_each = local.roles_github

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = flatten([for s in each.value.subs : [
        s,
        # Subject imutável: repo:<org>@<org_id>/<repo>@<repo_id>:...
        replace(s, "/^repo:([^/]+)/([^:]+):/", "repo:$1@*/$2@*:"),
      ]])
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.roles_github

  name                 = each.key
  assume_role_policy   = data.aws_iam_policy_document.confia_github[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github" {
  for_each = local.roles_github

  role       = aws_iam_role.github[each.key].name
  policy_arn = each.value.politica
}

resource "aws_iam_role_policy" "github_state" {
  for_each = local.roles_github

  name   = "acesso-state"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.acesso_state[each.key].json
}

data "aws_iam_policy_document" "acesso_state" {
  for_each = local.roles_github

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    actions = concat(
      ["s3:GetObject"],
      each.value.state.escrita ? ["s3:PutObject", "s3:DeleteObject"] : []
    )
    resources = [for p in each.value.state.prefixos : "${aws_s3_bucket.state.arn}/${p}*"]
  }

  statement {
    actions = concat(
      ["kms:Decrypt", "kms:DescribeKey"],
      each.value.state.escrita ? ["kms:Encrypt", "kms:GenerateDataKey"] : []
    )
    resources = [aws_kms_key.state.arn]
  }
}
