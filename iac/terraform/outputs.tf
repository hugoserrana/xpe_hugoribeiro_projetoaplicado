output "api_alb_dns" {
  description = "DNS público do ALB da API"
  value       = module.ecs.alb_dns_name
}

output "api_ecr_repository" {
  description = "Repositório ECR para push da imagem da API"
  value       = module.ecs.ecr_repository_url
}

output "dashboard_url" {
  description = "URL do dashboard (CloudFront)"
  value       = "https://${module.storage.cloudfront_domain}"
}

output "dashboard_bucket" {
  description = "Bucket S3 do dashboard (alvo do sync do build)"
  value       = module.storage.dashboard_bucket
}

output "uploads_bucket" {
  value = module.storage.uploads_bucket
}

output "aurora_endpoint" {
  value = module.database.cluster_endpoint
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "sns_topic_arn" {
  value = aws_sns_topic.notificacoes.arn
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.this.id
}
