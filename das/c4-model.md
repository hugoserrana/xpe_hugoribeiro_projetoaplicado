# 03 — Modelo C4

Notação **C4 Model** (Simon Brown): níveis de Contexto, Contêineres e
Componentes. O nível de Código é representado pela própria organização de
pacotes do MVP (`mvp/backend/internal`).

> **Diagramas draw.io:** os três níveis estão versionados em
> [`c4-model.drawio`](c4-model.drawio) (uma página por nível) e exportados em
> PNG: [nível 1](c4-nivel1-contexto.png) · [nível 2](c4-nivel2-conteineres.png)
> · [nível 3](c4-nivel3-componentes.png). Os diagramas Mermaid abaixo são a
> versão renderizável no próprio GitHub.

## 3.1 Nível 1 — Contexto do Sistema

```mermaid
C4Context
    title Morô — Diagrama de Contexto

    Person(morador, "Morador", "Proprietário, locatário ou dependente")
    Person(sindico, "Síndico / Administradora", "Gestão do condomínio")
    Person(operacao, "Equipe Operacional", "Porteiro, zelador, segurança")

    System(moro, "Plataforma Morô", "Gestão condominial multitenant (web + mobile)")

    System_Ext(cognito, "Amazon Cognito", "Identidade e login social")
    System_Ext(whats, "WhatsApp Business API", "Mensageria")
    System_Ext(fcm, "FCM / APNs", "Push notifications")
    System_Ext(ses, "Amazon SES", "E-mail transacional")
    System_Ext(cam, "Câmeras IP (NVR local)", "Streams RTSP/HLS")

    Rel(morador, moro, "Usa", "HTTPS")
    Rel(sindico, moro, "Gerencia", "HTTPS")
    Rel(operacao, moro, "Opera", "HTTPS")

    Rel(moro, cognito, "Autentica via", "OIDC/OAuth2")
    Rel(moro, whats, "Notifica via", "API")
    Rel(moro, fcm, "Envia push via", "API")
    Rel(moro, ses, "Envia e-mail via", "API")
    Rel(moro, cam, "Agrega streams de", "HLS")
```

![C4 Nível 1 — Contexto](c4-nivel1-contexto.png)

## 3.2 Nível 2 — Contêineres

```mermaid
C4Container
    title Morô — Diagrama de Contêineres

    Person(usuario, "Usuários", "Morador, Síndico, Operação")

    System_Boundary(moro, "Plataforma Morô") {
        Container(mobile, "App Mobile", "Flutter", "iOS + Android, base única")
        Container(web, "Dashboard Web", "React + Vite", "Gestão para síndico/administradora")
        Container(cdn, "CloudFront + S3", "CDN", "Entrega do dashboard e assets")
        Container(alb, "Application Load Balancer", "AWS ALB", "Entrada HTTPS, health checks")
        Container(api, "API REST", "Go (chi)", "Regras de negócio, RBAC, multitenancy")
        Container(worker, "Notification Worker", "Go", "Consome SQS e despacha multicanal")
        ContainerDb(aurora, "Aurora PostgreSQL", "Serverless v2", "Dados transacionais, isolados por tenant_id")
        ContainerDb(redis, "ElastiCache Redis", "Cache", "Cache multicamada, sessões efêmeras")
        Container(sns, "SNS + SQS", "Mensageria", "Fan-out de eventos de domínio")
        Container(s3, "S3 Uploads", "Object Storage", "Anexos: fotos, comprovantes, documentos")
    }

    System_Ext(cognito, "Amazon Cognito", "Identidade")
    System_Ext(canais, "FCM/APNs · WhatsApp · SES", "Canais de notificação")

    Rel(usuario, mobile, "Usa", "HTTPS")
    Rel(usuario, web, "Usa", "HTTPS")
    Rel(web, cdn, "Servido por")
    Rel(mobile, alb, "Chama API", "HTTPS/JSON")
    Rel(web, alb, "Chama API", "HTTPS/JSON")
    Rel(alb, api, "Encaminha", "HTTP")
    Rel(api, aurora, "Lê/escreve", "SQL/TLS")
    Rel(api, redis, "Cacheia", "RESP")
    Rel(api, s3, "Armazena anexos", "S3 API")
    Rel(api, sns, "Publica eventos")
    Rel(sns, worker, "Entrega via SQS")
    Rel(worker, canais, "Despacha")
    Rel(api, cognito, "Valida tokens")
```

![C4 Nível 2 — Contêineres](c4-nivel2-conteineres.png)

## 3.3 Nível 3 — Componentes (Contêiner: API REST)

```mermaid
C4Component
    title Morô — Componentes da API REST (Go)

    Container_Boundary(api, "API REST (Go)") {
        Component(router, "Router", "chi", "Roteamento, middlewares, CORS")
        Component(authmw, "Auth Middleware", "Go", "Valida JWT, injeta claims, RequireTenant/RequirePapel")
        Component(authsvc, "Auth Service", "Go", "Login (bcrypt), seleção de tenant, RBAC")
        Component(moradores, "Moradores", "Go", "F14 — pessoas, unidades, vínculos")
        Component(ocorrencias, "Ocorrências", "Go", "F01 — workflow + timeline")
        Component(mural, "Mural", "Go", "F03 — avisos + recibo de ciente")
        Component(encomendas, "Encomendas", "Go", "F05 — ciclo de vida")
        Component(financeiro, "Financeiro", "Go", "F16 — lançamentos + agregações")
        Component(assembleia, "Assembleia", "Go", "F02 — pautas, voto ponderado, quórum")
        Component(visitantes, "Visitantes", "Go", "F08 — convites, validação, acessos")
        Component(rondas, "Rondas", "Go", "F11 — rotas, check-in, dashboard")
        Component(portaria, "Portaria", "Go", "F12 — comunicação portaria↔morador")
        Component(notif, "Notificações", "Go", "F18 — central transversal (in-app + preferências)")
        Component(db, "DB Pool", "pgxpool", "Conexões com Aurora, retry")
    }

    ContainerDb(aurora, "Aurora PostgreSQL", "Serverless v2", "")
    Container(sns, "SNS", "Mensageria", "")

    Rel(router, authmw, "Aplica")
    Rel(authmw, authsvc, "Usa")
    Rel(router, moradores, "Encaminha")
    Rel(router, ocorrencias, "Encaminha")
    Rel(router, encomendas, "Encaminha")
    Rel(router, assembleia, "Encaminha")
    Rel(router, visitantes, "Encaminha")
    Rel(router, rondas, "Encaminha")
    Rel(router, portaria, "Encaminha")
    Rel(moradores, db, "Consulta")
    Rel(encomendas, notif, "Publica notificação")
    Rel(portaria, notif, "Publica notificação")
    Rel(visitantes, notif, "Publica notificação")
    Rel(notif, db, "Consulta")
    Rel(notif, sns, "Publica evento (produção)")
    Rel(db, aurora, "TLS")
```

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
