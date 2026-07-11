# 05 — Decisões Arquiteturais (ADRs)

As decisões arquiteturalmente significativas são registradas como **ADRs**
(Architecture Decision Records, formato MADR) neste documento. Cada ADR captura
o contexto, as opções consideradas, a decisão e suas consequências — preservando
a **rastreabilidade do raciocínio** exigida pela banca.

| ADR | Título                                         | Status   |
| --- | ---------------------------------------------- | -------- |
| [001](#adr-001-—-backend-em-go)        | Backend em Go (event-driven, stateless) | Aceito |
| [002](#adr-002-—-mobile-em-flutter)    | Mobile em Flutter (vs. React Native)    | Aceito |
| [003](#adr-003-—-arquitetura-orientada-a-eventos-não-real-time)      | Arquitetura orientada a eventos (não real-time) | Aceito |
| [004](#adr-004-—-infraestrutura-100%-aws-cloud-native)  | Infraestrutura 100% AWS cloud-native    | Aceito |
| [005](#adr-005-—-multitenancy-por-`tenant_id`-banco-compartilhado)      | Multitenancy por `tenant_id` (banco compartilhado) | Aceito |
| [006](#adr-006-—-autenticação-jwt-+-cognito-login-social)  | Autenticação JWT + Cognito (login social) | Aceito |
| [007](#adr-007-—-clean-architecture-+-solid-backend-e-mobile) | Clean Architecture + SOLID (backend e mobile) | Aceito |
| [008](#adr-008-—-migrations-versionadas-golang-migrate)        | Migrations versionadas (golang-migrate) | Aceito |
| [009](#adr-009-—-redux-para-estado-global-react-e-flutter) | Redux para estado global (React e Flutter) | Aceito |

> Decisões futuras (ex.: particionamento de tabelas de alto volume, escolha de
> gateway de pagamento para o marketplace freemium) serão adicionadas como novas
> ADRs ao longo das Sprints.


---

## ADR-001 — Backend em Go

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

A spec (§8) admite **Go** ou **Spring Boot (Java)** para o backend event-driven.
O serviço precisa: escalar horizontalmente em ECS Fargate, ter baixo consumo de
memória (custo), inicialização rápida (Auto Scaling responsivo) e boa
concorrência para I/O (banco, filas, integrações de notificação).

## Opções consideradas

| Opção        | Prós                                                      | Contras                                       |
| ------------ | -------------------------------------------------------- | --------------------------------------------- |
| **Go**       | Binário estático pequeno; cold start ~ms; concorrência por goroutines; baixo footprint | Ecossistema de frameworks mais enxuto         |
| Spring Boot  | Ecossistema maduro; produtividade; familiaridade         | JVM: maior memória, cold start; imagens maiores |
| Node.js      | Produtividade; mesmo idioma do front                      | Modelo single-thread para CPU; tipagem opcional |

## Decisão

Adotar **Go** para a API. Em ECS Fargate, o binário estático compilado
(`CGO_ENABLED=0`) em imagem `distroless` resulta em **imagens mínimas**,
**cold start de milissegundos** (favorecendo o Auto Scaling — RNF-P05/E02) e
**baixo custo de memória** por tarefa.

A organização é **por feature** (`internal/<feature>`), com middlewares de
autenticação/RBAC centralizados, e o acesso a dados via `pgxpool`.

## Consequências

- ✅ Custo de compute reduzido e escala responsiva.
- ✅ Superfície de ataque menor (imagem distroless, sem shell).
- ⚠️ Menos "mágica" de framework: validações e wiring são explícitos (trade-off
  aceito em favor de previsibilidade).
- 🔗 Sustenta [ADR-003](adr-003-event-driven.md) (publicação de eventos não-bloqueante).

## Evidência no MVP

[`mvp/backend/internal/`](../../../mvp/backend/internal) ·
[`Dockerfile` distroless](../../../mvp/backend/Dockerfile)


---

## ADR-002 — Mobile em Flutter

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

O Morô precisa de apps **iOS e Android** com UX consistente e foco em
**acessibilidade** (usuários idosos / baixa familiaridade digital — RNF-A01/A02).
O orçamento e o prazo favorecem **base de código única**.

## Opções consideradas

| Opção          | Prós                                                      | Contras                                  |
| -------------- | -------------------------------------------------------- | ---------------------------------------- |
| **Flutter**    | Compilação **AOT** para binário nativo; UI consistente entre plataformas; base única Dart; performance em telas complexas | Curva de aprendizado de Dart            |
| React Native   | Reuso de conhecimento React; comunidade grande            | Bridge JS; inconsistências de UI por plataforma; performance inferior em UI complexa |
| Nativo (2 apps)| Performance máxima                                        | Custo/manutenção dobrados; fora do orçamento |

## Decisão

Adotar **Flutter**. A compilação **AOT** para binários nativos garante
performance, a **base única** reduz custo e tempo, e a renderização própria
(Skia/Impeller) assegura **UX idêntica** entre Android e iOS — alinhada ao
requisito de acessibilidade. React Native foi **descartado**.

## Consequências

- ✅ Um time entrega as duas plataformas; menor TCO.
- ✅ UX consistente favorece onboarding de usuários não-digitais.
- ✅ Cache local com `flutter_cache_manager` + Hive (camada de cache do RNF-E04).
- ⚠️ Dependência do ecossistema Dart/Flutter (mitigado pela maturidade e adoção crescente no Brasil).

## Evidência

Decisão consolidada em [`../../spec.md §8 e §11`](../../../spec.md). O MVP entrega o
cliente **web** (dashboard React); o app Flutter é o cliente mobile da visão completa.


---

## ADR-003 — Arquitetura orientada a eventos (não real-time)

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

Muitas operações do domínio condominial produzem **efeitos colaterais
assíncronos**: ao abrir uma ocorrência, registrar uma encomenda ou publicar um
aviso, é preciso **notificar** pessoas por múltiplos canais (push, WhatsApp,
e-mail, SMS — F18). Tratar isso de forma síncrona acoplaria cada feature aos
provedores de notificação e degradaria a latência (RNF-P01/P02).

## Opções consideradas

| Opção                         | Prós                                            | Contras                                        |
| ----------------------------- | ----------------------------------------------- | ---------------------------------------------- |
| **Event-driven (SNS/SQS)**    | Desacopla produtor/consumidor; resiliência (DLQ, retry); escala independente | Complexidade operacional adicional             |
| Real-time (WebSocket)         | Atualização instantânea                          | Desnecessário ao domínio; conexões persistentes caras; mais frágil |
| Síncrono direto               | Simplicidade inicial                             | Acoplamento; latência; falha de canal derruba a request |

## Decisão

Adotar **arquitetura orientada a eventos** com **Amazon SNS (fan-out) → SQS**.
A API publica **eventos de domínio**; um **Notification Worker** consome a fila e
despacha pelos canais conforme a preferência do usuário (F18-RF02), com
**fallback** push→WhatsApp→e-mail (F18-RF05) e **DLQ** para mensagens
problemáticas. **Não** se adota real-time: o domínio é naturalmente assíncrono.

## Consequências

- ✅ Features não conhecem os provedores de notificação — baixo acoplamento (RNF-M04).
- ✅ Resiliência: retry e **DLQ** (RNF-D05); picos absorvidos pela fila.
- ✅ Escala independente entre API e worker.
- ⚠️ Garantia *at-least-once* exige **idempotência** nos consumidores (adotada no MVP via `ON CONFLICT`/updates condicionais).
- ⚠️ Eventual consistência nas notificações (aceitável para o domínio).

## Evidência

Tópico/fila/DLQ em [`iac/terraform/main.tf`](../../../iac/terraform/main.tf). No MVP,
os pontos de publicação de evento estão marcados no código (ex.: registro de
encomenda em [`usecase/encomendas.go`](../../../mvp/backend/internal/usecase/encomendas.go)).


---

## ADR-004 — Infraestrutura 100% AWS cloud-native

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

O Morô precisa escalar para **dezenas de milhares de condomínios** (RNF-E01) com
**alta disponibilidade** (RNF-D01) e **operação enxuta** (time pequeno). É
necessário decidir entre operar infraestrutura própria/k8s ou apoiar-se em
**managed services**.

## Opções consideradas

| Opção                              | Prós                                               | Contras                                  |
| ---------------------------------- | -------------------------------------------------- | ---------------------------------------- |
| **AWS managed (ECS Fargate, Aurora, etc.)** | Sem gestão de servidores; HA gerenciada; escala automática; ecossistema integrado | Lock-in de fornecedor                    |
| Kubernetes (EKS) auto-gerido       | Portabilidade; flexibilidade                        | Sobrecarga operacional alta para time pequeno |
| Multi-cloud                        | Evita lock-in                                       | Complexidade e custo desproporcionais ao estágio |

## Decisão

Adotar **100% AWS, cloud-native**, com **ECS Fargate** (compute sem servidores),
**Aurora PostgreSQL Serverless v2** (banco gerenciado com escala automática),
**ALB**, **S3/CloudFront**, **ElastiCache**, **SNS/SQS**, **Cognito** e
**Secrets Manager**. Toda a infraestrutura é descrita em **Terraform** (RNF-M01).

## Consequências

- ✅ HA multi-AZ gerenciada; foco do time no produto, não em servidores.
- ✅ Escala automática de compute (Fargate) e banco (Serverless v2).
- ✅ Reprodutibilidade e revisão via IaC.
- ⚠️ **Lock-in** AWS: mitigado pelo uso de PostgreSQL (padrão), contêineres OCI
  (portáveis) e isolamento das integrações atrás de interfaces.
- 🔗 Habilita o modelo de escalabilidade do [Capacity Planning](../../sprint-3/08-capacity-planning.md).

## Evidência

[`iac/terraform/`](../../../iac/terraform) — módulos `network`, `database`, `ecs`,
`storage` + recursos de cache/mensageria/auth. Validado com `terraform validate`.


---

## ADR-005 — Multitenancy por `tenant_id` (banco compartilhado)

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

A plataforma serve milhares de condomínios (tenants) sobre **um único ambiente
de produção** (spec §8). É preciso garantir **isolamento de dados** entre tenants
(RNF-S02) com **custo e operação viáveis** em escala (RNF-E01).

## Opções consideradas

| Modelo                                  | Isolamento | Custo/Operação        | Escala (10k tenants)        |
| --------------------------------------- | ---------- | --------------------- | --------------------------- |
| **Banco compartilhado + `tenant_id`**   | Lógico     | Baixo                 | Excelente                   |
| Schema por tenant                       | Médio      | Médio (migrações ×N)  | Degrada com milhares        |
| Banco por tenant                        | Forte      | Alto                  | Inviável em escala          |

## Decisão

Adotar **banco compartilhado com discriminador `condominio_id`** em todas as
tabelas de domínio. O **tenant ativo é derivado do JWT** (claim `condominio_id`,
preenchido na seleção de condomínio) e aplicado **no middleware/handlers** —
**nunca** a partir de parâmetros do cliente.

Controles de isolamento:

1. `RequireTenant` bloqueia rotas sem tenant ativo.
2. Todas as queries filtram por `condominio_id = $tenant`.
3. Operações por ID validam pertencimento ao tenant (defesa contra IDOR).

## Consequências

- ✅ Custo e operação ótimos em escala; uma migração para todos.
- ✅ Isolamento forte **se** a disciplina de filtragem for mantida (centralizada no middleware).
- ⚠️ Risco de vazamento por *query* sem filtro: mitigado por revisão e, em
  evolução, por **RLS (Row-Level Security)** do PostgreSQL como defesa em profundidade.
- 🔗 Base para o seletor de condomínio do [ADR-006](adr-006-auth-jwt-cognito.md).

## Evidência

[`delivery/httpapi/middleware.go`](../../../mvp/backend/internal/delivery/httpapi/middleware.go) (`TenantID`
vem do claim) · filtros `WHERE condominio_id = $1` em todos os handlers.


---

## ADR-006 — Autenticação JWT + Cognito (login social)

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

A acessibilidade é requisito de negócio (RNF-A01): reduzir a **fricção de
onboarding** para usuários com baixa familiaridade digital. Ao mesmo tempo, a API
precisa ser **stateless** para escalar horizontalmente (RNF-E02) e o sistema deve
suportar **múltiplos condomínios por usuário** (F19-RF10).

## Opções consideradas

| Opção                                  | Prós                                          | Contras                              |
| -------------------------------------- | --------------------------------------------- | ------------------------------------ |
| **JWT (API) + Cognito (identidade/social)** | API stateless; login social gerenciado; padrões OIDC | Revogação de JWT exige estratégia (TTL curto + refresh) |
| Sessão server-side                     | Revogação trivial                             | Estado compartilhado; atrito com escala horizontal |
| IdP próprio do zero                    | Controle total                                | Custo/segurança de reimplementar OAuth/OIDC |

## Decisão

Adotar **JWT** (HS256 no MVP; RS256/JWK em produção) para autorizar chamadas à API
de forma **stateless**, e **Amazon Cognito** como provedor de identidade com
**login social** (Google, e futuramente WhatsApp/Facebook). Senhas locais usam
**bcrypt custo 12** (RNF-S01).

Fluxo em dois passos: **login** → token sem tenant + lista de condomínios →
**seleção de condomínio** → token **escopado** (claims `condominio_id` + `papel`),
que habilita as rotas multitenant ([ADR-005](adr-005-multitenancy.md)).

## Consequências

- ✅ API stateless escala sem sessão compartilhada.
- ✅ Onboarding de baixa fricção via login social gerenciado.
- ✅ O papel viaja no token, simplificando o RBAC nos handlers.
- ⚠️ **Revogação**: mitigada por **TTL curto** + **refresh token** (evolução);
  no MVP, TTL de 24h.
- ⚠️ Segredo de assinatura deve residir no **Secrets Manager** (RNF-S03) — feito na IaC.

## Evidência

[`infra/security/jwt.go`](../../../mvp/backend/internal/infra/security/jwt.go),
[`delivery/httpapi/auth_handler.go`](../../../mvp/backend/internal/delivery/httpapi/auth_handler.go) (login + select) ·
Cognito + JWT secret na [IaC](../../../iac/terraform/main.tf).


---

## ADR-007 — Clean Architecture + SOLID (backend e mobile)

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

A primeira versão do backend tinha os handlers HTTP acessando o banco
diretamente (SQL dentro do handler). Funciona e é testável de ponta a ponta, mas
acopla regra de negócio, protocolo (HTTP) e persistência (SQL) na mesma camada —
dificultando testes de unidade, troca de tecnologia e evolução. Como o projeto é
de uma **pós em Arquitetura de Software**, a organização do código é, ela
própria, um artefato avaliado. Decidiu-se adotar **Clean Architecture** guiada
por **SOLID** no backend Go **e** no novo app Flutter.

## Decisão

Estruturar ambos os códigos em camadas concêntricas, com a dependência sempre
apontando **para dentro** (Dependency Rule):

```
            ┌─────────────────────────────────────────────┐
            │ delivery / presentation (HTTP, Widgets)      │
            │   ┌───────────────────────────────────────┐  │
            │   │ usecase (regras de aplicação + RBAC)   │  │
            │   │   ┌─────────────────────────────────┐  │  │
            │   │   │ domain (entidades, ports, regras)│  │  │
            │   │   └─────────────────────────────────┘  │  │
            │   └───────────────────────────────────────┘  │
            │ infra (postgres, security, http client)      │
            └─────────────────────────────────────────────┘
```

| Camada (Go / Flutter)                    | Responsabilidade                                  |
| ---------------------------------------- | ------------------------------------------------- |
| `domain`                                 | Entidades, **ports** (interfaces), regras puras (ex.: máquina de estados de ocorrência, voto válido) |
| `usecase` / `presentation.state`         | Orquestração + **autorização (RBAC)** como regra de aplicação |
| `infra` (`postgres`, `security`) / `data`| Implementações concretas dos ports (pgx, bcrypt, JWT, HTTP) |
| `delivery` (`httpapi`) / `presentation`  | Tradução protocolo ↔ caso de uso; mapeamento de erro de domínio → HTTP |
| `cmd/api/main.go` / `core/di`            | **Composition root**: instancia e injeta as dependências |

### SOLID na prática

- **S (Single Responsibility):** cada caso de uso encapsula uma ação; o handler
  só traduz HTTP; o repositório só persiste.
- **O (Open/Closed):** novas features entram como novos pacotes/arquivos sem
  alterar os existentes.
- **L (Liskov):** qualquer implementação de `OcorrenciaRepository` é
  substituível (Postgres em produção, *fake* em teste).
- **I (Interface Segregation):** ports pequenos e focados por agregado
  (`MuralRepository`, `RondaRepository`, …) em vez de uma interface gigante.
- **D (Dependency Inversion):** os casos de uso dependem de **interfaces de
  domínio**, nunca de pgx/HTTP; o `main`/`injector` faz a ligação.

## Consequências

- ✅ **Testabilidade:** regras testáveis sem banco/HTTP (ex.: `auth_controller_test.dart`
  usa um `FakeAuthRepository`; a máquina de estados é função pura).
- ✅ **Troca de infra** sem tocar no domínio (ex.: trocar pgx por outro driver,
  ou JWT por Cognito, mudando só a camada `infra`).
- ✅ **RBAC centralizado** na camada de aplicação (`Actor.Autorizar`), não
  espalhado em middlewares de rota.
- ⚠️ **Mais arquivos e indireção** — custo aceito em favor de clareza e evolução.
- ⚠️ **Trade-off pragmático:** as entidades de domínio carregam `json`/JSON tags
  para serialização direta na borda, evitando uma explosão de DTOs. Documentado
  como concessão consciente.

## Evidência

- Backend: [`mvp/backend/internal/{domain,usecase,infra,delivery}`](../../../mvp/backend/internal)
- Mobile: [`mvp/mobile/lib/features/*/{domain,data,presentation}`](../../../mvp/mobile/lib)
- Validação: build + `go vet` OK; **33/33** testes de integração; `flutter analyze`
  sem issues; `flutter test` 2/2.


---

## ADR-008 — Migrations versionadas (golang-migrate)

- **Status:** Aceito
- **Data:** 2026-06-29
- **Etapa DT:** Prototipação

## Contexto

A primeira versão criava o schema e os dados de demonstração via **init scripts**
do PostgreSQL (`/docker-entrypoint-initdb.d`). Esse mecanismo:

- roda **uma única vez**, na criação do volume — alterar um `.sql` não reaplica;
- **não versiona** o schema (sem saber "qual versão está aplicada"), sem `up/down`;
- **mistura** DDL (estrutura) com seed (dados de demonstração).

Inadequado para produção e para um ambiente que evolui em sprints.

## Decisão

Adotar **golang-migrate** com migrations **versionadas e embutidas** no binário
da API (`go:embed` + `source/iofs`), executadas **no startup** antes de servir
tráfego. O **seed** de demonstração foi **separado** das migrations e só roda sob
`RUN_SEED=true`, sendo **idempotente** (guard pelo CNPJ do condomínio).

```
mvp/backend/internal/migrations/   0001_init.up/down.sql · 0002_core_r2.up/down.sql (embutidos)
mvp/backend/internal/seeddata/     seed.sql (demo, idempotente)
mvp/backend/internal/platform/database/migrate.go   Migrate() + Seed()
```

| Aspecto            | Antes (init scripts)        | Depois (golang-migrate)              |
| ------------------ | --------------------------- | ------------------------------------ |
| Versionamento      | nenhum                      | tabela `schema_migrations` (v1, v2…) |
| Reaplicação        | só em volume novo           | aplica pendentes em qualquer banco   |
| Rollback           | inexistente                 | arquivos `*.down.sql`                |
| Estrutura × dados  | misturados                  | `migrations/` × `seeddata/`          |
| Distribuição       | arquivos montados no Postgres | embutidos no binário (`go:embed`)  |

## Consequências

- ✅ Schema evolui de forma **rastreável e reproduzível** (RNF-M01); o mesmo
  binário leva suas migrations.
- ✅ Funciona igual em local (podman) e produção (Aurora) — em produção pode-se
  rodar como *init container* ou *job* antes do deploy.
- ✅ Seed isolado e idempotente: seguro reiniciar; some em produção (`RUN_SEED`
  ausente).
- ⚠️ **Pin de versão:** `golang-migrate v4.17.1` — versões ≥ 4.18 exigem Go ≥ 1.24;
  fixado para compatibilidade com a toolchain Go 1.22 do projeto.
- ⚠️ A API ganha a responsabilidade de migrar no boot; em frotas grandes,
  preferir um passo de migração único no pipeline para evitar corrida entre réplicas.

## Evidência

[`migrate.go`](../../../mvp/backend/internal/platform/database/migrate.go) ·
[`migrations/`](../../../mvp/backend/internal/migrations) ·
boot validado: `migrations aplicadas` + `schema_migrations.version = 2`,
idempotência confirmada em restart.


---

## ADR-009 — Redux para estado global (React e Flutter)

- **Status:** Aceito
- **Data:** 2026-07-01
- **Etapa DT:** Prototipação

## Contexto

O estado global de sessão (pessoa autenticada, tenant/condomínio selecionado,
papel RBAC) era gerido de forma diferente em cada cliente: **Context API**
(React) no dashboard e **ChangeNotifier/provider** (Flutter) no app. Dois
padrões distintos para o mesmo problema aumentam o custo cognitivo do time,
dificultam a paridade Web/Mobile (driver do projeto) e espalham transições de
estado por métodos mutáveis, sem um ponto único de auditoria. Além disso, o
plano de escala do produto (novas features consumindo a mesma sessão, badge de
notificações compartilhado entre telas) exige previsibilidade nas mudanças de
estado.

Opções consideradas:

1. **Manter Context API + provider** — sem dependências novas, porém dois
   modelos mentais e mutação implícita de estado.
2. **Zustand (web) + provider (mobile)** — leve, mas mantém a assimetria entre
   plataformas.
3. **Redux nos dois clientes** — um único padrão (store única, estado imutável,
   ações explícitas, reducers puros), com implementações maduras em ambos os
   ecossistemas: **Redux Toolkit** (React) e **redux + flutter_redux +
   redux_thunk** (Flutter).

## Decisão

Adotar **Redux** como padrão de gerenciamento de **estado global** nos dois
clientes:

- **Dashboard React:** Redux Toolkit (`@reduxjs/toolkit` + `react-redux`) com
  slice `auth` (sessão/tenant/papel) e thunks assíncronos (`login`,
  `selecionarCondominio`); hooks tipados (`useAppSelector`/`useAppDispatch`).
- **App Flutter:** store única (`Store<AppState>`) com `combineReducers` manual
  por fatia (`auth`, `notificacoes`), `redux_thunk` para efeitos assíncronos e
  `flutter_redux` (`StoreProvider`/`StoreConnector`) na camada de widgets. Os
  thunks orquestram os **casos de uso** existentes da Clean Architecture
  (ADR-007) — a Dependency Rule é preservada: `presentation → usecase → domain`.

**Escopo deliberado:** Redux governa o **estado global compartilhado entre
features** (sessão, notificações/badge). Estado efêmero de uma única tela
(formulários, listas locais) permanece na camada `presentation` da própria
feature (useState/controllers locais), seguindo a recomendação da própria
comunidade Redux de não globalizar estado local.

## Consequências

**Positivas**

- Um único padrão mental de estado nas duas plataformas (paridade Web/Mobile).
- Transições explícitas e auditáveis: ação → reducer puro → novo estado
  (time-travel debugging, logging de ações, testes de reducer sem UI).
- Testabilidade: o fluxo de login/logout é testado despachando thunks contra
  um store real com repositório falso, sem rede nem widgets.
- O logout propaga limpeza a todas as fatias (ex.: notificações zeradas),
  eliminando vazamento de estado entre sessões/tenants.

**Negativas / mitigação**

- Mais verbosidade (ações, reducers, thunks) que Context/provider — mitigada
  pelo Redux Toolkit no React e por fatias pequenas no Flutter.
- Curva de aprendizado para quem não conhece o padrão — mitigada pela simetria
  entre as plataformas (aprende-se uma vez).


---

