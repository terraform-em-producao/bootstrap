# bootstrap

O "ovo" da galinha: o que precisa existir **antes** de qualquer automação.

| Arquivo | Cria |
|---|---|
| `state.tf` | Bucket S3 do state (versionado, KMS, só TLS, sem acesso público) e a chave KMS |
| `dns.tf` | Zona `terraform.gomex.me` |
| `github-oidc.tf` | Roles que o GitHub Actions assume via OIDC: `github-atlantis-plan`, `github-atlantis-apply`, `github-drift` |
| `atlantis-exec.tf` | Roles que o Atlantis assume por stack: `terraform-exec-groundwork`, `-dev`, `-prod` |

## Quem aplica

Uma pessoa admin, **localmente**, raramente. Este é o único repo com apply manual,
e é por isso que ele é pequeno: só o que a automação não consegue criar para si mesma.

## Primeira execução

O backend aponta para o bucket que este código cria. Então:

```bash
mv backend.tf backend.tf.depois
terraform init
terraform apply

mv backend.tf.depois backend.tf
terraform init -migrate-state   # responde "yes": o state local vai para o S3
rm terraform.tfstate*
```

Depois, delegue a zona: crie em `gomex.me` um registro **NS** `terraform` com os valores de `terraform output name_servers`.

## Lock de state

`use_lockfile = true`: o lock é um objeto `.tflock` no próprio S3 (Terraform ≥ 1.10). Não precisa mais de DynamoDB.

## Menor privilégio, na prática

```
atlantis-task ──assume──► terraform-exec-groundwork  (VPC, budgets, buckets tep-shared-*)
              ──assume──► terraform-exec-dev         (buckets tep-dev-*)
              ──assume──► terraform-exec-prod        (buckets tep-prod-*)

GitHub Actions (OIDC)
  atlantis @ pull_request         ──► github-atlantis-plan   (leitura)
  atlantis @ environment:producao ──► github-atlantis-apply  (admin)
  groundwork|infra-live @ main    ──► github-drift           (leitura)
```

Precisa de uma permissão nova numa stack? PR aqui, apply local. A conversa sobre permissão vira código revisado.
