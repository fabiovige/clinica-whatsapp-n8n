# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A complete WhatsApp automated scheduling system for Brazilian medical clinics, built on **n8n** workflows. No custom application code — logic lives entirely in n8n JSON workflow files and a PostgreSQL schema. The main artifacts to edit are `workflows/*.json` and `database/schema.sql`.

## Stack

- **n8n** — workflow orchestrator (all business logic)
- **Evolution API** (non-official) or **Meta WhatsApp Cloud API** (official) — WhatsApp gateway
- **PostgreSQL 16** — state, appointments, audit log
- **Redis 7** — cache for conversation state (optional but recommended)
- **Caddy** — reverse proxy with automatic HTTPS
- **Google Calendar** — real appointment storage (one calendar per specialty)
- **OpenAI** (optional) — FAQ answers via gpt-4o-mini

## Running the system

```bash
# First-time setup
cp .env.example .env && nano .env
nano caddy/Caddyfile  # replace SEU_DOMINIO with your domain

# Start core services (PostgreSQL + Redis + n8n + Caddy)
docker compose up -d

# Start with Evolution API gateway too
docker compose --profile evolution up -d

# Start with admin UIs (Portainer + Adminer)
docker compose --profile management up -d

# Follow n8n logs
docker compose logs -f n8n

# Restart everything
docker compose restart

# Wipe all data and start fresh
docker compose down -v && docker compose up -d
```

## Database

```bash
# Connect to the clinic DB
docker exec -it clinica-postgres psql -U postgres -d clinica

# Apply schema manually (auto-applied on first compose up via docker-entrypoint-initdb.d)
psql -h localhost -U postgres -d clinica -f database/schema.sql

# Key daily metrics view
SELECT * FROM v_daily_metrics LIMIT 7;
```

## Workflow architecture

Workflows call each other via HTTP webhooks. Workflow 01 is always the entry point.

| File | Trigger | Role |
|---|---|---|
| `01-orchestrator-main.json` | Webhook `POST /webhook/clinica-webhook` | Receives all WhatsApp messages, detects intent via regex/menu number, routes to sub-workflows |
| `01-meta-orchestrator.json` | Webhook (Meta variant) | Same as above but for Meta Cloud API format |
| `02-booking-flow.json` | HTTP call from 01 | Creates Google Calendar event + inserts into `appointments` |
| `02-meta-booking.json` | HTTP call from 01 | Meta variant of booking |
| `03-cancel-reschedule.json` | HTTP call from 01 | Cancels or reschedules; updates Calendar and DB |
| `04-reminders.json` | Cron every 30min | Sends 24h and 2h reminder messages; sets `reminder_*_sent = true` |
| `04-meta-reminders.json` | Cron every 30min | Meta variant of reminders |
| `05-ai-faq-feedback.json` | HTTP call from 01 + Cron 6h | FAQ via OpenAI; post-consultation feedback collection |

**Internal webhook URLs:**
- `POST /webhook/clinica-booking` → workflow 02
- `POST /webhook/clinica-cancel` → workflow 03
- `POST /webhook/clinica-reschedule` → workflow 03
- `POST /webhook/clinica-ai-faq` → workflow 05

## WhatsApp gateway choice

There are **two parallel sets** of workflows — one for each gateway. Import only the set you need:

| Use case | Workflows to import |
|---|---|
| Testing / no approval needed | `01-orchestrator-main`, `02-booking-flow`, `04-reminders` |
| Production / official | `01-meta-orchestrator`, `02-meta-booking`, `04-meta-reminders` |
| Both share | `03-cancel-reschedule`, `05-ai-faq-feedback` |

## Conversation state machine

States in `conversation_state.state`: `INITIAL → MENU → AWAITING_SPECIALTY → AWAITING_DATE → AWAITING_TIME → AWAITING_NAME → AWAITING_CONFIRM → CONFIRMED`

Special transitions (from any state):
- Text "menu" → `MENU`
- 30min inactivity → `INITIAL` (via `expires_at`)
- "atendente"/"humano" → `IN_HUMAN_QUEUE`

State context (collected data) is stored as JSONB in `conversation_state.context`.

## Key database tables

- `patients` — phone is the unique key (format: `5511999998888`, no `+`)
- `doctors` — each doctor has a `google_calendar_id` (dedicated calendar email)
- `appointments` — status: `pending | confirmed | cancelled | completed | no_show`; tracks reminder sent flags and feedback
- `conversation_state` — one row per phone, expires after 30min
- `conversation_log` — full audit of inbound/outbound messages
- `human_queue` — transfer-to-human requests with priority

## Customizing specialties

Edit the **"Resolve Especialidade + Datas"** Code node in workflow 02:

```js
'7': { name: 'Nutrição', duration: 30, calendarId: 'nutri@clinica.com.br' }
```

Also update the `doctors` table with the new doctor's `google_calendar_id`.

## n8n environment variables

Set in **n8n Settings → Variables** (accessible in workflows as `{{ $env.VAR_NAME }}`):

```
EVO_HOST         # Evolution API hostname in docker network (e.g. "evolution")
EVO_INSTANCE     # Evolution instance name (e.g. "clinica")
EVO_APIKEY       # Evolution API key
META_PHONE_ID    # Meta WhatsApp phone number ID
META_TOKEN       # Meta permanent access token
META_VERIFY_TOKEN # Webhook verification token (any strong string)
OPENAI_API_KEY   # Optional, for FAQ AI
```

## Troubleshooting

```bash
# Bot not responding
docker compose logs -f n8n | grep -i webhook
docker compose ps

# Check Evolution API connection
docker compose logs -f evolution

# Backup database
bash scripts/backup-db.sh
```

| Symptom | Likely cause |
|---|---|
| "Horário ocupado" always | Wrong `google_calendar_id` in `doctors` table |
| Messages duplicated | Webhook registered twice in Evolution Manager |
| Google permission error | Re-authorize OAuth credential in n8n |
| IA not answering | Invalid/out-of-credit OpenAI key |

## Scaling notes

For >500 messages/day:
- Move `conversation_state` to Redis (faster than Postgres upserts)
- Switch n8n to queue mode: `EXECUTIONS_MODE=queue` + Redis workers
- Add message deduplication via Redis SET on `message_id` with TTL 24h
