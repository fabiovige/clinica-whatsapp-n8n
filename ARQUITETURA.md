# 🧬 Arquitetura Técnica · Visão detalhada

> Referência rápida pra quem vai mexer no código. Atualizado em: 2026-06.

---

## Stack

```
┌─────────────────────────────────────────────────────────────┐
│  Paciente (WhatsApp)                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │ mensagem
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Evolution API  · gateway WhatsApp self-hosted              │
│  · recebe mensagens (webhook)                               │
│  · envia mensagens (HTTP POST)                              │
└──────────────────────┬──────────────────────────────────────┘
                       │ POST /webhook/clinica-webhook
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  n8n  · orquestrador de fluxos                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 01 Orchestrator  → detecta intenção, roteia         │    │
│  │ 02 Booking       → Google Calendar + DB             │    │
│  │ 03 Cancel/Re     → Google Calendar + DB             │    │
│  │ 04 Reminders     → cron a cada 30min                │    │
│  │ 05 IA + Feedback → OpenAI + feedback pós            │    │
│  └─────────────────────────────────────────────────────┘    │
└────────┬─────────────────┬──────────────────┬───────────────┘
         │                 │                  │
         ▼                 ▼                  ▼
   ┌──────────┐    ┌──────────────┐   ┌─────────────┐
   │ Postgres │    │Google Calendar│   │ OpenAI API  │
   │ (estado, │    │ (agenda real  │   │ (FAQ c/ IA) │
   │  log,    │    │  dos médicos) │   │             │
   │  audit)  │    └──────────────┘   └─────────────┘
   └──────────┘
```

---

## Fluxo de uma mensagem

```
[1] Evolution envia POST → /webhook/clinica-webhook
    payload: { event: "messages.upsert", data: { key: {...}, message: {...} } }

[2] Workflow 01:
    ├─ Normaliza payload (extrai phone, text, pushName)
    ├─ Filtra: só messages.upsert, ignora grupos e fromMe
    ├─ Detecta intenção (regex + número do menu)
    ├─ Upsert em patients (phone único)
    ├─ Busca conversation_state
    └─ Roteia:
       ├─ AGENDAR      → responde com menu de especialidades
       ├─ CONSULTAR    → workflow 03 (action=list)
       ├─ CANCELAR     → responde com lista de agendamentos
       ├─ REAGENDAR    → workflow 03 (action=reschedule)
       ├─ INFO         → responde FAQ estático
       ├─ HUMANO       → notifica equipe
       └─ DESCONHECIDA → mostra menu

[3] Workflows auxiliares (chamados via HTTP webhook):
    POST /webhook/clinica-booking     → cria evento no Calendar
    POST /webhook/clinica-cancel      → cancela
    POST /webhook/clinica-reschedule  → atualiza
    POST /webhook/clinica-ai-faq      → responde com IA

[4] Workflow 04 (cron 30min):
    ├─ Busca appts que precisam de lembrete 24h
    ├─ Busca appts que precisam de lembrete 2h
    ├─ Envia WhatsApp
    └─ Marca reminder_X_sent = true no DB

[5] Workflow 05 (cron 6h):
    └─ Pra cada consulta finalizada nas últimas 6h,
       envia pedido de feedback
```

---

## Schema do banco (resumo)

```
patients          → cadastro do paciente (phone único)
doctors           → cadastro de médicos + google_calendar_id
appointments      → consultas agendadas (status, lembretes, feedback)
conversation_state → state machine por telefone
conversation_log  → log de tudo que entrou/saiu
followups         → follow-ups agendados
human_queue       → fila de transferência pra humano
v_daily_metrics   → view com KPIs diários
```

Detalhamento completo em [`database/schema.sql`](database/schema.sql).

---

## State machine (conversation_state)

```
INITIAL
  ↓ primeira msg
MENU
  ↓ opção 1
AWAITING_SPECIALTY
  ↓ número
AWAITING_DATE
  ↓ data
AWAITING_TIME
  ↓ hora
AWAITING_NAME (se não tiver nome)
  ↓ nome
AWAITING_CONFIRM
  ↓ confirma
CONFIRMED → reseta pra MENU após 5min

(qualquer estado + texto "menu" → volta pro MENU)
(qualquer estado + 30min sem msg → expira e volta pro INITIAL)
(qualquer estado + "atendente"/"humano" → IN_HUMAN_QUEUE)
```

Implementação atual: **simplificada** — o workflow 01 detecta intenção via regex/menu e chama sub-workflows. Pra produção com conversas multi-step, ative o nó de persistência de estado no workflow 01 (tabela `conversation_state` já existe).

---

## IDs e configuração

### Calendars (1 por especialidade)

```
clinico-geral@clinica.com.br  → 30min slots
cardio@clinica.com.br          → 40min slots
derma@clinica.com.br           → 30min slots
gineco@clinica.com.br          → 40min slots
pediatra@clinica.com.br        → 30min slots
orto@clinica.com.br            → 40min slots
```

Crie um calendar pra cada e compartilhe com a service account do GCP.

### Variáveis de ambiente (n8n)

```
EVO_HOST          # hostname da Evolution API (ex: "evo" no docker)
EVO_INSTANCE     # nome da instância (ex: "clinica")
EVO_APIKEY       # apikey da Evolution
OPENAI_API_KEY   # opcional, pra IA
```

---

## Performance

| Métrica | Esperado |
|---|---|
| Latência webhook → resposta | < 2s |
| Throughput | ~50 msg/seg (single instance n8n) |
| Custo OpenAI (gpt-4o-mini) | ~R$ 0,50 / 1000 interações |
| Custo total mensal | R$ 80-250 / mês (clínica pequena-média) |

Pra escalar >500 msg/dia, considere:

- Mover `conversation_state` pra **Redis**
- Usar **queue mode** do n8n (modo fila com workers)
- Cache de FAQs (Redis) — perguntas repetidas não vão pra OpenAI

---

## Segurança

| Camada | Controle |
|---|---|
| Transporte | HTTPS obrigatório (Cloudflare Tunnel / Traefik) |
| Auth Evolution | API Key em header `apikey` |
| Auth Google | Service Account (sem usuário interativo) |
| Auth n8n | User + senha (mude o default!) |
| DB | Senha forte, bind em localhost ou rede privada |
| Logs | Mascarar telefone/email em produção |
| LGPD | `consent_lgpd` no primeiro contato |
| Backup | pg_dump diário, retenção 30 dias |

---

## Monitoramento sugerido

- **Uptime**: UptimeRobot no `/healthz` do n8n
- **Logs**: Loki + Grafana ou Datadog
- **Métricas**: Prometheus + node_exporter no host
- **Erros**: n8n → Slack/Telegram via nó Error Trigger
- **Quota OpenAI**: alerta em platform.openai.com quando >80% do budget

---

## Quando cada workflow é chamado

| Origem | Workflow | Trigger |
|---|---|---|
| Mensagem WhatsApp | 01 | Webhook (sempre) |
| Agendar | 02 | HTTP call do 01 |
| Cancelar/Remarcar | 03 | HTTP call do 01 |
| Lembrete 24h/2h | 04 | Cron a cada 30min |
| FAQ com IA | 05 | HTTP call (opcional) |
| Feedback pós-consulta | 05 | Cron a cada 6h |

---

## Roadmap técnico

- [ ] Migrar state machine pra Redis (mais rápido que Postgres)
- [ ] Adicionar **whisper.cpp** pra transcrever áudio automaticamente
- [ ] Implementar **deduplicação** de mensagens (Redis SET com message_id, TTL 24h)
- [ ] **Dashboard** (Metabase ou Superset) lendo do Postgres
- [ ] **Rate limiter** por telefone (max 30 msgs/hora)
- [ ] **Múltiplas clínicas** (multi-tenant) — adicionar `clinic_id` em tudo
- [ ] **API REST** própria pra integrar com site/app

---

Mais detalhes sobre cada workflow? Olha o JSON individual — cada nó tem comentário no nome.
