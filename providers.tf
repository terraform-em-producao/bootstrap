provider "aws" {
  region = var.regiao

  default_tags {
    tags = {
      projeto     = "terraform-em-producao"
      repositorio = "${var.github_org}/bootstrap"
      gerenciado  = "terraform"
    }
  }
}
