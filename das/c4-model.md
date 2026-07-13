# 03 — Modelo C4

Notação **C4 Model** (Simon Brown): níveis de Contexto, Contêineres e
Componentes. O nível de Código é representado pela própria organização de
pacotes do MVP (`mvp/backend/internal`).

> Os três níveis estão versionados em [`c4-model.drawio`](c4-model.drawio)
> (uma página por nível), no mesmo estilo draw.io da
> [topologia AWS](das.drawio) da Sprint 1.

## 3.1 Nível 1 — Contexto do Sistema

Pessoas (Morador, Síndico/Administradora, Equipe Operacional), a Plataforma
Morô e os sistemas externos: Amazon Cognito (identidade/login social),
WhatsApp Business API, FCM/APNs (push), Amazon SES (e-mail) e câmeras IP
(NVR local, streams RTSP/HLS).

![C4 Nível 1 — Contexto](c4-nivel1-contexto.png)

## 3.2 Nível 2 — Contêineres

App Mobile (Flutter · Redux), Dashboard Web (React + Vite · Redux Toolkit)
servido por CloudFront + S3, ALB na entrada HTTPS, API REST (Go/chi · ECS
Fargate) com regras de negócio/RBAC/multitenancy, Notification Worker (Go ·
ECS Fargate) consumindo SQS, Aurora PostgreSQL Serverless v2 (dados isolados
por `tenant_id`), ElastiCache Redis (cache multicamada), SNS + SQS (fan-out
de eventos de domínio) e S3 Uploads (anexos).

![C4 Nível 2 — Contêineres](c4-nivel2-conteineres.png)

## 3.3 Nível 3 — Componentes (Contêiner: API REST)

Router (chi) e Auth Middleware (JWT, `RequireTenant`/`RequirePapel`) na
borda; componentes de feature — Moradores (F14), Ocorrências (F01), Mural
(F03), Encomendas (F05), Financeiro (F16), Assembleia (F02), Visitantes
(F08), Rondas (F11), Portaria (F12) — e a central transversal de
Notificações (F18), todos acessando o Aurora via DB Pool (pgxpool) e
publicando eventos no SNS.

![C4 Nível 3 — Componentes](c4-nivel3-componentes.png)

> **Mapa componente → código:** cada componente corresponde a um pacote em
> `mvp/backend/internal/`. O isolamento por pacote concretiza o RNF-M04
> (modularidade / baixo acoplamento).

## 3.4 Vista de implantação — Topologia AWS (draw.io, estilo AWS)

A vista de implantação (deployment) complementa o C4 com a topologia física na
AWS, produzida no **draw.io** com a biblioteca oficial de shapes AWS
(`mxgraph.aws4`) — editável em [`das.drawio`](das.drawio).

![Topologia AWS — Morô](das.gif)

Elementos representados: VPC multi-AZ com sub-redes privadas, ALB, ECS Fargate
(API e Notification Worker), Aurora PostgreSQL Serverless v2 (writer + réplica),
ElastiCache Redis, S3 + CloudFront, SNS→SQS com DLQ, Cognito, SES, Secrets
Manager, CloudWatch e ECR — espelhando 1:1 os módulos da [IaC](../iac/terraform/main.tf).

## 3.5 Decisões refletidas no C4

- A separação **API ↔ Notification Worker** materializa o estilo event-driven
  ([ADR-003](adrs.md)): a API não bloqueia para notificar.
- **CloudFront/S3** para o dashboard e **ALB→ECS** para a API seguem o padrão
  cloud-native ([ADR-004](adrs.md)).
- O **Auth Middleware** é o ponto único de aplicação de multitenancy e RBAC,
  evitando dispersão da regra de isolamento ([ADR-005](adrs.md)).
