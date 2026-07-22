# 09 — Custos AWS (estimativa)

Estimativa de custo mensal **on-demand** (região `us-east-1`, USD), para apoiar a
decisão de viabilidade do modelo **freemium**. Valores **aproximados** e de
ordem de grandeza — devem ser refinados com a *AWS Pricing Calculator* e medições
reais. Não incluem *Free Tier*.

## 9.1 Cenário de partida (early-stage: ~500 condomínios)

| Serviço                         | Configuração                                  | Custo/mês (USD) aprox. |
| ------------------------------- | --------------------------------------------- | ---------------------- |
| ECS Fargate (API)               | 2 tasks · 0,5 vCPU / 1 GB · 24×7              | ~30                    |
| Aurora Serverless v2            | ~0,5–1 ACU média · 2 instâncias               | ~90                    |
| Aurora storage + I/O            | ~20 GB + I/O moderado                          | ~10                    |
| Application Load Balancer       | 1 ALB + LCU baixo                              | ~20                    |
| NAT Gateway                     | 1 NAT + tráfego                                | ~35                    |
| ElastiCache Redis               | `cache.t4g.micro` 1 nó                         | ~12                    |
| S3 (uploads + dashboard)        | < 50 GB + requisições                           | ~5                     |
| CloudFront                      | Tráfego baixo                                   | ~10                    |
| SNS + SQS                       | Volume baixo                                    | ~2                     |
| Cognito                         | < 50k MAU (faixa gratuita generosa)            | ~0                     |
| Secrets Manager                 | ~2 segredos                                     | ~1                     |
| CloudWatch (logs/insights)      | Retenção 30 dias, volume moderado              | ~10                    |
| **Total estimado**              |                                               | **≈ US$ 225 – 270/mês**|

## 9.2 Cenário de escala (~10.000 condomínios, pico ~800 RPS)

| Serviço                         | Mudança em relação ao early-stage              | Custo/mês (USD) aprox. |
| ------------------------------- | ---------------------------------------------- | ---------------------- |
| ECS Fargate (API)               | média ~6 tasks (Auto Scaling 2→10)            | ~110                   |
| Aurora Serverless v2            | ~3–4 ACU média · 2 instâncias                  | ~520                   |
| Aurora storage + I/O            | ~300 GB + I/O elevado                           | ~120                   |
| ALB                             | LCU maior                                        | ~60                    |
| NAT Gateway                     | Tráfego maior (considerar NAT por AZ)           | ~80                    |
| ElastiCache Redis               | `cache.r7g.large` + réplica                     | ~210                   |
| S3 + CloudFront                 | Volume de anexos e entrega maiores              | ~120                   |
| SNS/SQS + worker (Fargate)      | Notificações em volume + 2 tasks worker         | ~60                    |
| Cognito                         | Faixa paga acima de 50k MAU                      | ~250                   |
| CloudWatch                      | Logs/Insights em escala                          | ~80                    |
| **Total estimado**              |                                                | **≈ US$ 1.700 – 2.000/mês** |

> Custo por condomínio em escala: **~US$ 0,18/mês**, compatível com o modelo
> freemium (anúncios contextuais + plano premium + marketplace).

## 9.3 Alavancas de otimização de custo

| Alavanca                                    | Economia esperada                                   |
| ------------------------------------------- | --------------------------------------------------- |
| **Compute Savings Plans / Fargate** (1–3 anos) | 20–50% sobre o compute estável                   |
| **Aurora I/O-Optimized**                    | Reduz custo quando o I/O domina a fatura            |
| **Fargate Spot** para o worker de notificação | Até ~70% no processamento assíncrono tolerante a interrupção |
| **Piso de ACU baixo** (0,5) fora de pico    | Banco "respira" conforme a carga                    |
| **TTL/retention** de logs e cache           | Controla custo de CloudWatch e ElastiCache          |
| **CloudFront cache hit alto**               | Reduz origem (S3/ALB) e egress                      |

## 9.4 Observações

- **Cognito** torna-se um custo relevante em escala (MAU): avaliar federação e
  estratégias de redução de MAU pagos.
- **Aurora** é o maior item em escala: o roteamento de leituras pesadas à réplica
  e o cache no Redis são essenciais para conter ACUs.
- O **NAT Gateway** é um custo fixo frequentemente subestimado: VPC endpoints
  (S3/ECR/Secrets) reduzem tráfego pelo NAT e devem ser adicionados na evolução.
