# Morô — Infraestrutura como Código (Terraform / AWS)

Provisiona a infraestrutura cloud-native descrita no DAS para a plataforma
Morô. Tudo é declarativo, versionado e reproduzível.

## Topologia provisionada

| Camada            | Recurso AWS                                   | Módulo / arquivo        |
| ----------------- | --------------------------------------------- | ----------------------- |
| Rede              | VPC multi-AZ, subnets pública/privada, NAT    | `modules/network`       |
| Banco             | Aurora PostgreSQL Serverless v2 (2 instâncias)| `modules/database`      |
| Compute           | ECS Fargate + ALB + Auto Scaling + ECR        | `modules/ecs`           |
| Web/Estático      | S3 + CloudFront (dashboard) + S3 (uploads)    | `modules/storage`       |
| Cache             | ElastiCache (Redis)                           | `main.tf`               |
| Mensageria        | SNS (fan-out) + SQS (+ DLQ)                    | `main.tf`               |
| Autenticação      | Cognito User Pool + App Client                | `main.tf`               |
| Segredos          | Secrets Manager (Aurora, JWT)                 | módulos `database`/`ecs`|

## Pré-requisitos

- Terraform >= 1.5
- Credenciais AWS configuradas (`aws configure` ou variáveis de ambiente)

## Uso

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste os valores

terraform init
terraform plan
terraform apply
```

## Saídas relevantes

`terraform output` expõe: `api_alb_dns`, `dashboard_url` (CloudFront),
`aurora_endpoint`, `redis_endpoint`, `sns_topic_arn`, `cognito_user_pool_id`.

## Observações de custo e segurança

- **Custo**: NAT Gateway único e Aurora Serverless v2 com piso de 0.5 ACU
  reduzem o gasto do ambiente. Estimativa detalhada será entregue no sprint 3.
- **Segurança**: bancos e tasks em subnets privadas; acesso ao Aurora apenas
  pela VPC; segredos no Secrets Manager (nunca em texto plano no estado de
  aplicação); S3 com block public access; CloudFront com OAC.
- **Estado remoto**: descomente o bloco `backend "s3"` em `versions.tf` para
  compartilhar o estado com lock no DynamoDB.
