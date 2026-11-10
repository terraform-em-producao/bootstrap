output "bucket_state" {
  value = aws_s3_bucket.state.id
}

output "kms_state_arn" {
  value = aws_kms_key.state.arn
}

output "zona_dns" {
  value = aws_route53_zone.org.name
}

output "name_servers" {
  description = "Cadastre estes NS para o registro terraform em gomex.me."
  value       = aws_route53_zone.org.name_servers
}

output "roles_github" {
  value = { for k, r in aws_iam_role.github : k => r.arn }
}

output "roles_exec" {
  value = { for k, r in aws_iam_role.exec : k => r.arn }
}
