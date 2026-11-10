# Zona da org. Fica no bootstrap porque a delegação (NS em gomex.me) é manual
# e feita uma vez só; se a zona fosse recriada, os NS mudariam.
resource "aws_route53_zone" "org" {
  name = var.dominio

  lifecycle {
    prevent_destroy = true
  }
}
