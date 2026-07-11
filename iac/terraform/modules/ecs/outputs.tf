output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.api.name
}

output "worker_ecr_repository_url" {
  value = one(aws_ecr_repository.worker[*].repository_url)
}

output "worker_service_name" {
  value = one(aws_ecs_service.worker[*].name)
}
