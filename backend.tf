# O bootstrap cria o próprio bucket que guarda o state dele.
# Primeira execução: veja o README (init sem backend -> apply -> migrate-state).
terraform {
  backend "s3" {
    bucket       = "terraform-em-producao-tfstate-907079643427"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/terraform-state"
    use_lockfile = true
  }
}
