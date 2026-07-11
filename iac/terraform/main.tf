# =====================================================================
# Morô — Infraestrutura AWS (cloud-native). Ver das/07 e das/09.
# Topologia: VPC multi-AZ · Aurora PostgreSQL · ECS Fargate + ALB ·
#            S3/CloudFront · ElastiCache Redis · SNS/SQS · Cognito.
# =====================================================================

module "network" {
  source   = "./modules/network"
  project  = var.project
  vpc_cidr = var.vpc_cidr
  azs      = var.azs
}

module "database" {
  source       = "./modules/database"
  project      = var.project
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids
  ingress_cidr = module.network.vpc_cidr
  db_name      = var.db_name
  db_username  = var.db_username
}

module "ecs" {
  source             = "./modules/ecs"
  project            = var.project
  region             = var.region
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  api_image          = var.api_image
  desired_count      = var.api_desired_count
  cpu                = var.api_cpu
  memory             = var.api_memory
  db_secret_arn      = module.database.secret_arn
  db_endpoint        = module.database.cluster_endpoint
  db_name            = var.db_name
  db_username        = var.db_username

  # Notification Worker (F18) — Sprint 3
  worker_image     = var.worker_image
  notif_queue_arn  = aws_sqs_queue.notificacoes.arn
  notif_queue_url  = aws_sqs_queue.notificacoes.id
  notif_queue_name = aws_sqs_queue.notificacoes.name
  ses_sender       = var.ses_sender_email
}

module "storage" {
  source  = "./modules/storage"
  project = var.project
}

# ---------------------------------------------------------------------
# F18 — Central de Notificações: SNS (fan-out) + SQS (processamento async).
# ---------------------------------------------------------------------
resource "aws_sns_topic" "notificacoes" {
  name = "${var.project}-notificacoes"
}

resource "aws_sqs_queue" "notificacoes_dlq" {
  name = "${var.project}-notificacoes-dlq"
}

resource "aws_sqs_queue" "notificacoes" {
  name                       = "${var.project}-notificacoes"
  visibility_timeout_seconds = 60
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notificacoes_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sns_topic_subscription" "fila" {
  topic_arn = aws_sns_topic.notificacoes.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notificacoes.arn
}

data "aws_iam_policy_document" "sqs_policy" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notificacoes.arn]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.notificacoes.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "notificacoes" {
  queue_url = aws_sqs_queue.notificacoes.id
  policy    = data.aws_iam_policy_document.sqs_policy.json
}

# ---------------------------------------------------------------------
# Cache — Amazon ElastiCache (Redis) para cache multicamada.
# ---------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-redis"
  subnet_ids = module.network.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg"
  description = "Acesso ao Redis a partir da VPC"
  vpc_id      = module.network.vpc_id
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project}-redis-sg" }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project}-redis"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
}

# ---------------------------------------------------------------------
# F18 — E-mail transacional: Amazon SES (remetente verificado).
# ---------------------------------------------------------------------
resource "aws_ses_email_identity" "notificacoes" {
  email = var.ses_sender_email
}

# ---------------------------------------------------------------------
# F19 — Autenticação: Amazon Cognito (login social via federação).
# ---------------------------------------------------------------------
resource "aws_cognito_user_pool" "this" {
  name = "${var.project}-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_uppercase = true
    require_symbols   = false
  }

  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name            = "${var.project}-app"
  user_pool_id    = aws_cognito_user_pool.this.id
  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
  supported_identity_providers = ["COGNITO", "Google"]
}
