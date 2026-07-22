# 10 — Aprendizados de Engenharia

Registro consolidado dos aprendizados técnicos acumulados na construção do MVP,
da IaC e do app mobile. Complementa as **Lições Aprendidas** de negócio do
`spec.md §11` com lições de **implementação e processo**.

## 10.1 Arquitetura e código

- **Clean Architecture compensa quando o domínio tem regras.** Mover RBAC,
  máquina de estados e validações para `usecase`/`domain` tornou tudo testável
  sem banco nem HTTP (ver [ADR-007](adrs.md)). O
  custo (mais arquivos/indireção) é justificado pela clareza e pela facilidade de
  troca de infraestrutura.
- **Autorização é regra de negócio, não de transporte.** Centralizar o RBAC em
  `Actor.Autorizar(...)` na camada de aplicação — em vez de middlewares por rota —
  deixou a permissão explícita, testável e perto da regra que a exige.
- **Trade-off consciente de DTOs.** Serializar entidades de domínio diretamente
  (com `json` tags) evitou uma explosão de DTOs de apresentação. É uma concessão
  à pureza, registrada para não ser confundida com descuido.
- **Multitenancy seguro = tenant do token, nunca do payload.** O `condominio_id`
  vem sempre do JWT; qualquer ID no corpo é validado contra o tenant ativo. Isso
  fecha a porta para IDOR entre condomínios.

## 10.2 Banco de dados

- **Init scripts não são migrations.** `docker-entrypoint-initdb.d` roda só na
  criação do volume e não versiona nada. Migrar para **golang-migrate** embutido
  no binário deu versionamento, `up/down` e reprodutibilidade
  ([ADR-008](adrs.md)).
- **Separar schema de seed.** DDL versionado em `migrations/`; dados de demo em
  `seeddata/`, idempotentes (guard por CNPJ) e atrás de `RUN_SEED`. Reiniciar o
  ambiente deixou de duplicar dados.
- **Hash bcrypt entre ferramentas.** O bcrypt do Go (`golang.org/x/crypto/bcrypt`)
  aceita as variantes `$2a$`, `$2b$` e `$2y$`. Por isso foi possível gerar o hash
  do seed com o `htpasswd` do Apache (`$2y$`) e validá-lo no login do Go sem
  reimplementar bcrypt — desde que o hash tenha os 60 caracteres completos (um
  truncamento silencioso quebra a verificação).

## 10.3 Processo de validação (depuração)

- **Valide o arranjo de teste antes de suspeitar do código.** Um suposto
  "bug de roteamento 405" custou tempo: era o `curl` fazendo **GET** em endpoints
  POST **sem corpo** (sem `-d` nem `-X POST`). Um `405 Method Not Allowed` com
  header `Allow: POST` é o sintoma exato desse engano — a rota existe, o método é
  que não bate. A aplicação estava correta o tempo todo.
- **Containers órfãos enganam.** Resultados intermitentes (200 vs 405 para a mesma
  requisição) vinham de um **container antigo** ainda ligado à porta. Recriar o
  ambiente do zero (remover container + volume) antes de cada bateria eliminou o
  ruído.
- **Toolchain importa no pin de dependências.** `golang-migrate ≥ 4.18` exige
  Go ≥ 1.24; com Go 1.22 foi preciso fixar `v4.17.1`. Ler o `go.mod` da dependência
  evita o erro "toolchain upgrade needed".
- **`flutter analyze` precisa de `pub get` na mesma execução do container.** O
  cache de pacotes (`.pub-cache`) vive dentro do container e não persiste entre
  execuções isoladas; rodar `analyze` sozinho reporta dezenas de falsos
  "Target of URI doesn't exist". Encadear `pub get && analyze` resolve.

## 10.4 Estado de front-end e automação de evidências (Sprint 1)

- **Dois padrões de estado para o mesmo problema é assimetria, não pluralismo.**
  O dashboard React usava Context API e o app Flutter usava
  ChangeNotifier/provider para a mesma sessão (pessoa + tenant + papel). A
  unificação em **Redux** nos dois clientes ([ADR-009](adrs.md))
  deu um único modelo mental — estado imutável, ações explícitas, reducers
  puros — e tornou o fluxo login/logout testável despachando thunks contra um
  store real com repositório falso, sem UI nem rede.
- **Redux global ≠ tudo no Redux.** Só o estado **compartilhado entre features**
  (sessão, badge de notificações) foi para o store; estado efêmero de tela
  (formulários, listas locais) permaneceu na camada `presentation` de cada
  feature. Globalizar estado local só aumenta acoplamento.
- **Logout deve propagar para todas as fatias.** Com o reducer de notificações
  reagindo à ação de logout, dados de um tenant não vazam para a sessão
  seguinte — um requisito de multitenancy que ficou trivial no Redux.
- **Estado de SPA em memória se perde no reload — e a automação sente.** Os
  screenshots automatizados do dashboard falhavam ao usar `page.goto()` após o
  login: a seleção de condomínio vivia só em memória. A automação precisou
  navegar **pela própria SPA** (cliques), respeitando o ciclo de vida real do
  estado.
- **Flutter Web renderiza em canvas.** Não há DOM para automação consultar;
  interações de teste E2E via navegador funcionam por coordenadas (ou exigem a
  árvore de semântica habilitada). Vale planejar a estratégia de testes E2E
  antes de depender dela.
- **Exportador do draw.io tem armadilhas de identificador.** Um id de célula
  `push` colide com propriedades de objetos JavaScript do exportador
  (`Typed.setId is not a function`). Ids de células devem evitar nomes de
  membros nativos (`push`, `map`, `filter`...).
- **CORS de origem única é ótimo em produção e chato em bancada.** Com
  `CORS_ORIGIN` fixo em uma única origem, validar um segundo front (Flutter
  web) exigiu servi-lo na mesma origem do dashboard. Registrado para o DAS:
  ambientes de teste precisam de política de CORS própria.

## 10.5 Validação sem toolchains locais

Todo o projeto foi compilado e testado **em contêineres** (Go, Node, Flutter,
Terraform, PostgreSQL) via podman, sem instalar SDKs na máquina. Isso garante
reprodutibilidade e espelha o pipeline de CI. Resumo do que foi exercitado:

| Artefato      | Verificação                                              | Resultado     |
| ------------- | ------------------------------------------------------- | ------------- |
| Backend Go    | `go build`, `go vet`, 33 testes de integração           | ✅            |
| Migrations    | aplicação no boot + idempotência em restart             | ✅ (v2)       |
| Dashboard     | `vite build`                                            | ✅ (50 módulos)|
| Mobile Flutter| `flutter analyze`, `flutter test`                       | ✅ (3/3)      |
| IaC Terraform | `terraform validate`                                    | ✅            |
| Stack completa| login ponta a ponta pelo proxy do dashboard             | ✅            |

> **Atualização (Sprint 3):** o `terraform validate` foi reexecutado em
> 08/07/2026 (contêiner `hashicorp/terraform:1.9`) após a inclusão do
> Notification Worker (F18), da identidade SES e do Auto Scaling por
> profundidade de fila — configuração válida.

## 10.6 Documentação incremental e diagramas como código (Sprints 2–3)

- **Toggles LaTeX separam produção de publicação.** Todo o conteúdo do
  relatório (Sprints 2–3 e Considerações Finais) foi produzido de uma vez e
  ocultado por bloco (`\newif\ifshowsprinttwo` etc.); cada entrega semanal é
  só ativar um toggle e recompilar. O build completo de revisão usa
  `pdflatex -jobname=relatorio_full "\def\fullbuild{1}\input{relatorio.tex}"`
  — mesmo fonte, dois PDFs, zero edição manual (editar toggles à mão para
  gerar a versão full e reverter depois se mostrou frágil e foi eliminado).
- **Exportação multi-página do draw.io nomeia por página.** Um único
  `c4-model.drawio` com três páginas (Contexto, Contêineres, Componentes)
  exporta `<arquivo>-<página>.png`; manter os nomes de página estáveis é o
  contrato com o `\includegraphics` do relatório.
- **Verificação visual do Gate é automatizável.** Extrair páginas-chave do
  PDF com Ghostscript (`gs -dFirstPage=N -dLastPage=N -sDEVICE=png16m`) e
  inspecioná-las cobre a regra do Gate ("verificado no PDF compilado") sem
  paginar 60 páginas à mão.
- **Diagramas largos no template XPE.** Kanbans e o ER excedem `\textwidth`;
  `\makebox[\textwidth][c]{\includegraphics[width=1.25\textwidth]{...}}`
  centraliza o excedente nas margens sem quebrar o grid do template.
- **Auto Scaling de worker escala pela fila, não por CPU.** Para o
  Notification Worker (F18), a métrica correta é
  `ApproximateNumberOfMessagesVisible` (target tracking customizado), não CPU:
  um worker ocioso com fila cheia é exatamente o caso que CPU não detecta.
  O recurso é condicional na IaC (`count` por `notif_queue_arn`), permitindo
  ambientes sem o worker.
- **Artefatos organizados por entrega evitam vazamento de escopo.** Com
  entregas incrementais, o repositório passou a espelhar os toggles do
  relatório: cada entrega contém exatamente os capítulos e diagramas dela,
  e o PDF de uma entrega só cita artefatos já publicados.
  Ocultar seções não basta se uma tabela visível referencia um artefato que
  só existe em entrega futura.
- **Links de documentação para código quebram em refatorações.** A migração
  do backend para Clean Architecture moveu arquivos que o DAS referenciava
  (`internal/auth/*` → `infra/security/`, `delivery/httpapi/`), deixando
  links mortos despercebidos. A correção veio com checagem automatizada de
  links relativos (extrair alvos de `](...)` e testar existência),
  incorporada à validação da documentação.
- **Evidência de diagrama = print do editor no navegador.** O formato de
  evidência do relatório passou a ser o diagrama **aberto no draw.io**
  (app.diagrams.net), capturado com Chrome headless: o hash
  `#R<xml-urlencoded>` abre o XML direto no editor sem diálogo de storage;
  Ctrl+A + Ctrl+Shift+H (Fit Selection) enquadra o conteúdo; clique em área
  vazia desfaz a seleção antes do print. Gotchas: em arquivo multipágina,
  selecionar a aba pelo **texto** e escolher o elemento DOM **mais interno**
  (um contêiner que engloba todas as abas também casa com `startsWith` e o
  clique cai na aba errada); a primeira página dispensa clique.
