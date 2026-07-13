# 06 — Vistas de Sequência

Fluxos dinâmicos das principais features, demonstrando como os componentes do
[Modelo C4](c4-model.md) colaboram em tempo de execução.

## 6.1 Autenticação e seleção de condomínio (F19)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant W as Dashboard (React)
    participant A as API (Go)
    participant DB as Aurora

    U->>W: e-mail + senha
    W->>A: POST /auth/login
    A->>DB: SELECT pessoa WHERE email
    DB-->>A: pessoa + senha_hash
    A->>A: bcrypt.Compare (custo 12)
    A->>DB: SELECT vínculos ativos (condomínios + papéis)
    DB-->>A: memberships
    A-->>W: token (sem tenant) + lista de condomínios
    alt vínculo único
        W->>A: POST /auth/select-condominio {id}
    else múltiplos
        U->>W: escolhe condomínio
        W->>A: POST /auth/select-condominio {id}
    end
    A->>DB: valida vínculo e obtém papel
    DB-->>A: papel
    A-->>W: token escopado (condominio_id + papel)
    W->>A: GET /dashboard (Bearer token)
    A-->>W: KPIs do tenant
```

## 6.2 Abertura de ocorrência + notificação assíncrona (F01 → F18)

```mermaid
sequenceDiagram
    autonumber
    actor M as Morador
    participant W as Cliente
    participant A as API
    participant DB as Aurora
    participant SNS as SNS
    participant Q as SQS
    participant K as Notification Worker
    participant C as Canais (push/WhatsApp/e-mail)

    M->>W: descreve ocorrência
    W->>A: POST /ocorrencias (Bearer)
    A->>A: RequireTenant + valida payload
    A->>DB: BEGIN; INSERT ocorrencia (status=ABERTA)
    A->>DB: INSERT ocorrencia_evento (timeline)
    A->>DB: COMMIT
    A-)SNS: publica evento "ocorrencia.aberta" (async)
    A-->>W: 201 Created {id, status}
    SNS->>Q: fan-out
    Q->>K: entrega mensagem
    K->>K: resolve preferências + fallback
    K->>C: despacha notificação
    Note over K,Q: falha → retry; após N → DLQ (RNF-D05)
```

## 6.3 Transição de status com RBAC (F01)

```mermaid
sequenceDiagram
    autonumber
    actor S as Síndico
    participant A as API
    participant DB as Aurora

    S->>A: POST /ocorrencias/{id}/status {EM_ANDAMENTO}
    A->>A: RequirePapel(SINDICO,...) 
    A->>DB: SELECT status atual (WHERE id AND condominio_id)
    DB-->>A: status = EM_ANALISE
    A->>A: valida transição (máquina de estados)
    alt transição válida
        A->>DB: BEGIN; UPDATE status; INSERT evento; COMMIT
        A-->>S: 200 {novo status}
    else inválida
        A-->>S: 409 Conflict (transição inválida)
    end
```

## 6.4 Recibo de leitura no mural (F03)

```mermaid
sequenceDiagram
    autonumber
    actor M as Morador
    participant A as API
    participant DB as Aurora

    M->>A: POST /mural/{id}/ciente
    A->>DB: INSERT aviso_ciente SELECT ... WHERE aviso do tenant ON CONFLICT DO NOTHING
    DB-->>A: rows affected (0 ou 1)
    alt primeira vez
        A-->>M: 200 {ciente}
    else já ciente / inexistente
        A-->>M: 200 {ja_ciente}  %% idempotente
    end
```

## 6.5 Ciclo de vida da encomenda (F05)

```mermaid
sequenceDiagram
    autonumber
    actor P as Porteiro
    actor M as Morador
    participant A as API
    participant DB as Aurora
    participant SNS as SNS

    P->>A: POST /encomendas {unidade, remetente, tipo}
    A->>A: RequirePapel(PORTEIRO,...) 
    A->>DB: INSERT encomenda (status=RECEBIDA)
    A-)SNS: evento "encomenda.recebida" → notifica morador
    A-->>P: 201 {id, RECEBIDA}
    M->>A: POST /encomendas/{id}/retirar
    A->>DB: UPDATE status=RETIRADA WHERE status<>RETIRADA (idempotente)
    alt atualizou
        A-->>M: 200 {RETIRADA}
    else já retirada
        A-->>M: 409 Conflict
    end
```
