# 02 — Requisitos

> Os requisitos funcionais detalhados por feature estão em
> [`../features.md`](../../features.md). Este capítulo consolida a **visão
> arquitetural** dos requisitos e formaliza os **Requisitos Não-Funcionais (RNF)**
> com metas mensuráveis — insumo direto para o [Capacity Planning](../sprint-3/08-capacity-planning.md)
> e o [Threat Model](../sprint-3/07-seguranca-threat-model.md).

## 2.1 Requisitos funcionais (visão por domínio)

| Domínio            | Features      | Capacidade central                                  |
| ------------------ | ------------- | --------------------------------------------------- |
| Identidade & Acesso| F19, F14      | Autenticação, RBAC, multitenancy, cadastro          |
| Comunicação        | F03, F12, F18 | Mural, portaria digital, notificações multicanal    |
| Governança         | F01, F02, F09 | Ocorrências, assembleia, enquetes                   |
| Operação           | F05, F08, F11, F15 | Encomendas, acesso de visitantes, rondas, escalas |
| Financeiro         | F16, F06      | Gastos, transparência, reservas com taxa            |
| Infraestrutura predial | F10, F13, F17 | Manutenção, vagas, câmeras                      |
| Conteúdo           | F04, F07      | Documentos, classificados                           |

## 2.2 Requisitos Não-Funcionais (RNF)

### Desempenho

| ID       | Requisito                                              | Meta                          |
| -------- | ------------------------------------------------------ | ----------------------------- |
| RNF-P01  | Latência de leitura (p95) das APIs de listagem          | ≤ 300 ms                      |
| RNF-P02  | Latência de escrita (p95)                               | ≤ 600 ms                      |
| RNF-P03  | Entrega de push notification (F18-RNF05)                | ≤ 5 s                         |
| RNF-P04  | Entrega de WhatsApp/SMS                                  | ≤ 30 s                        |
| RNF-P05  | Cold start aceitável das tarefas Fargate                | ≤ 30 s                        |

### Escalabilidade

| ID       | Requisito                                               | Meta                          |
| -------- | ------------------------------------------------------- | ----------------------------- |
| RNF-E01  | Capacidade de condomínios (tenants)                     | 10.000+ sem reengenharia      |
| RNF-E02  | Escala horizontal da API                                | Auto Scaling 2→10 tarefas (CPU 65%) |
| RNF-E03  | Escala do banco                                         | Aurora Serverless v2 0.5→4 ACU |
| RNF-E04  | Cache multicamada                                       | App (Hive) + Redis (ElastiCache) |

### Disponibilidade & Resiliência

| ID       | Requisito                                               | Meta                          |
| -------- | ------------------------------------------------------- | ----------------------------- |
| RNF-D01  | Disponibilidade mensal (SLO)                            | ≥ 99,9%                       |
| RNF-D02  | Topologia                                               | Multi-AZ (≥ 2 zonas)          |
| RNF-D03  | RPO (Recovery Point Objective)                          | ≤ 5 min (backup contínuo Aurora) |
| RNF-D04  | RTO (Recovery Time Objective)                           | ≤ 30 min                      |
| RNF-D05  | Tolerância a falha de canal de notificação              | Fallback push→WhatsApp→e-mail (F18-RF05) + DLQ |

### Segurança & Privacidade

| ID       | Requisito                                               | Meta                          |
| -------- | ------------------------------------------------------- | ----------------------------- |
| RNF-S01  | Senhas com bcrypt                                       | custo ≥ 12 (F19-RNF02)        |
| RNF-S02  | Isolamento de tenant                                    | 100% das queries filtradas por `tenant_id` |
| RNF-S03  | Segredos                                                | Secrets Manager; nunca em código/estado |
| RNF-S04  | Tráfego                                                 | TLS fim a fim (CloudFront/ALB HTTPS) |
| RNF-S05  | Rate limiting de login                                  | proteção brute force (F19-RNF03) |
| RNF-S06  | LGPD                                                    | consentimento, anonimização, exclusão |

### Manutenibilidade & Operação

| ID       | Requisito                                               | Meta                          |
| -------- | ------------------------------------------------------- | ----------------------------- |
| RNF-M01  | Infraestrutura reproduzível                             | 100% via Terraform (IaC)      |
| RNF-M02  | Observabilidade                                         | Logs centralizados (CloudWatch), Container Insights |
| RNF-M03  | Deploy                                                  | Imagens versionadas no ECR; rollout sem downtime |
| RNF-M04  | Modularidade do código                                  | Pacotes por feature, baixo acoplamento |

### Acessibilidade & UX

| ID       | Requisito                                               | Meta                          |
| -------- | ------------------------------------------------------- | ----------------------------- |
| RNF-A01  | Onboarding de usuário não-digital                       | Login social + convite; ≤ 3 passos |
| RNF-A02  | Consistência entre plataformas                          | Base única Flutter (iOS/Android) |

## 2.3 Rastreabilidade RNF → mecanismo arquitetural

| RNF        | Mecanismo / componente                                          | Onde no DAS / código              |
| ---------- | --------------------------------------------------------------- | --------------------------------- |
| RNF-E02    | ECS Fargate Auto Scaling (TargetTracking CPU)                   | [iac `modules/ecs`](../../iac/terraform/modules/ecs/main.tf) |
| RNF-E03    | Aurora Serverless v2 scaling configuration                      | [iac `modules/database`](../../iac/terraform/modules/database/main.tf) |
| RNF-S01    | `bcrypt.GenerateFromPassword(..., 12)`                          | [`infra/security/bcrypt.go`](../../mvp/backend/internal/infra/security/bcrypt.go) |
| RNF-S02    | `tenant_id` derivado do JWT, nunca do payload                   | [`delivery/httpapi/middleware.go`](../../mvp/backend/internal/delivery/httpapi/middleware.go) |
| RNF-D05    | SNS→SQS com DLQ (maxReceiveCount=5)                             | [iac `main.tf`](../../iac/terraform/main.tf) |
| RNF-M01    | Terraform modular                                               | [`iac/`](../../iac/)                 |
