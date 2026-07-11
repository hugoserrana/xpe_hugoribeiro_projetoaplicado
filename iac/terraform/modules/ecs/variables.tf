variable "project" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }

variable "api_image" {
  description = "Imagem da API no ECR. Vazio cria apenas o repositório (primeiro apply)."
  type        = string
  default     = ""
}
variable "desired_count" { type = number }
variable "cpu" { type = number }
variable "memory" { type = number }

variable "db_secret_arn" {
  description = "ARN do secret do Aurora (chave password injetada na task)"
  type        = string
}
variable "db_endpoint" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }

# ---------- Notification Worker (F18) ----------
variable "worker_image" {
  description = "Imagem do worker de notificações. Vazio cria apenas o repositório."
  type        = string
  default     = ""
}

variable "notif_queue_arn" {
  description = "ARN da fila SQS de notificações. Vazio desativa o worker."
  type        = string
  default     = ""
}

variable "notif_queue_url" {
  description = "URL da fila SQS de notificações"
  type        = string
  default     = ""
}

variable "notif_queue_name" {
  description = "Nome da fila SQS (dimensão do Auto Scaling por profundidade)"
  type        = string
  default     = ""
}

variable "ses_sender" {
  description = "Remetente verificado no SES para e-mails transacionais"
  type        = string
  default     = ""
}
