variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Prefixo de nomeação dos recursos"
  type        = string
  default     = "moro"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Zonas de disponibilidade utilizadas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "moro"
}

variable "db_username" {
  description = "Usuário administrador do Aurora"
  type        = string
  default     = "moro_admin"
}

variable "api_image" {
  description = "Imagem da API (ECR). Ex.: <acct>.dkr.ecr.<region>.amazonaws.com/moro-api:latest"
  type        = string
  default     = ""
}

variable "api_desired_count" {
  description = "Número desejado de tarefas Fargate da API"
  type        = number
  default     = 2
}

variable "api_cpu" {
  description = "CPU da task da API (unidades Fargate)"
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "Memória da task da API (MiB)"
  type        = number
  default     = 1024
}

variable "worker_image" {
  description = "Imagem do Notification Worker (ECR). Ex.: <acct>.dkr.ecr.<region>.amazonaws.com/moro-worker:latest"
  type        = string
  default     = ""
}

variable "ses_sender_email" {
  description = "Remetente verificado no SES para e-mails transacionais (F18)"
  type        = string
  default     = "notificacoes@moro.app"
}
