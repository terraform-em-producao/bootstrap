variable "regiao" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  type    = string
  default = "terraform-em-producao"
}

variable "dominio" {
  description = "Zona delegada para a org (o NS precisa ser cadastrado no DNS de gomex.me)."
  type        = string
  default     = "terraform.gomex.me"
}

variable "criar_provider_oidc" {
  description = "Só existe um provider OIDC do GitHub por conta. false reaproveita o que já existe."
  type        = bool
  default     = false
}

variable "nome_role_atlantis" {
  description = "Nome fixo da task role do Atlantis (criada no repo atlantis)."
  type        = string
  default     = "atlantis-task"
}
