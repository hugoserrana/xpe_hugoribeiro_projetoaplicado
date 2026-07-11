variable "project" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "ingress_cidr" {
  description = "CIDR autorizado a acessar o banco (tipicamente o CIDR da VPC)"
  type        = string
}
variable "db_name" { type = string }
variable "db_username" { type = string }

variable "min_capacity" {
  description = "Capacidade mínima Aurora Serverless v2 (ACUs)"
  type        = number
  default     = 0.5
}
variable "max_capacity" {
  description = "Capacidade máxima Aurora Serverless v2 (ACUs)"
  type        = number
  default     = 4
}
