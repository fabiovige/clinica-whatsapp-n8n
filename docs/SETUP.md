# 🔧 Setup completo · Passo a passo

> Guia detalhado pra colocar o sistema no ar do zero, mesmo que você nunca tenha usado n8n.

---

## Índice

1. [Pré-requisitos](#1-pré-requisitos)
2. [Subir a infraestrutura](#2-subir-a-infraestrutura)
3. [Configurar PostgreSQL](#3-configurar-postgresql)
4. [Configurar Google Calendar](#4-configurar-google-calendar)
5. [Configurar a Evolution API (WhatsApp)](#5-configurar-a-evolution-api-whatsapp)
6. [Instalar o n8n](#6-instalar-o-n8n)
7. [Importar os workflows](#7-importar-os-workflows)
8. [Configurar credenciais no n8n](#8-configurar-credenciais-no-n8n)
9. [Apontar webhook Evolution → n8n](#9-apontar-webhook-evolution--n8n)
10. [Testar end-to-end](#10-testar-end-to-end)
11. [Colocar em produção](#11-colocar-em-produção)

---

## 1. Pré-requisitos

Você vai precisar de:

- **Docker + Docker Compose** (recomendado) OU acesso a um VPS Linux
- **Domínio próprio** (produção) — ex: `atendimento.clinicavida.com.br`
- **Conta Google Workspace** com Google Calendar habilitado
- **Chip de WhatsApp Business** dedicado pra clínica (não use seu pessoal)
- **Acesso ao Meta Business Manager** (opcional, só pra API oficial)

Custo de servidor sugerido pra uma clínica média:

| Provider | Plano | Preço/mês |
|----------|-------|-----------|
| Hetzner | CX22 (2 vCPU, 4GB) | ~R$ 50 |
| Contabo | VPS M (4 vCPU, 8GB) | ~R$ 60 |
| DigitalOcean | Basic droplet | ~US$ 24 |
| AWS Lightsail | 2 vCPU, 4GB | ~US$ 20 |

---

## 2. Subir a infraestrutura

### Opção A — Docker Compose (recomendado)

Crie `docker-compose.yml` na raiz do projeto:

```yaml
version: "3.9"

services:
  postgres:
    image: postgres:16-alpine
    container_name: clinica-pg
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: clinica123
      POSTGRES_DB: clinica
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./database/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: clinica-n8n
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=clinica123
      - N8N_HOST=${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=America/Sao_Paulo
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168  # 7 dias
    ports:
      - "5678:5678"
    volumes:
      - n8ndata:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy

  evolution:
    image: atendai/evolution-api:latest
    container_name: clinica-evo
    restart: always
    environment:
      - AUTHENTICATION_API_KEY=${EVO_APIKEY}
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:clinica123@postgres:5432/evolution
      - CACHE_REDIS_ENABLED=false
      - LOG_LEVEL=info
    ports:
      - "8080:8080"
    volumes:
      - evodata:/evolution/instances
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  pgdata:
  n8ndata:
  evodata:
```

Crie `.env` na raiz:

```bash
EVO_APIKEY=gere-uma-chave-aleatoria-com-32-chars-aqui
N8N_HOST=atendimento.clinicavida.com.br
```

Suba tudo:

```bash
docker compose up -d
docker compose ps
docker compose logs -f n8n
```

### Opção B — Hostinger / Locaweb / VPS gerenciado

Se você usa um VPS sem Docker:

```bash
# PostgreSQL
sudo apt install postgresql
sudo -u postgres createuser -s n8n_user
sudo -u postgres createdb clinica -O n8n_user

# Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# n8n global
npm install -g n8n

# Evolution API (recomendo Docker só pra ela)
docker run -d --name evo -p 8080:8080 \
  -e AUTHENTICATION_API_KEY=sua-chave \
  atendai/evolution-api:latest
```

---

## 3. Configurar PostgreSQL

### Criar o banco da Evolution API também

```bash
docker exec -it clinica-pg psql -U postgres -c "CREATE DATABASE evolution;"
```

### Rodar o schema

```bash
# Se estiver com docker-compose, o schema já roda sozinho no init
# Se precisar rodar de novo:
docker exec -i clinica-pg psql -U postgres -d clinica < database/schema.sql
```

### Verificar

```bash
docker exec -it clinica-pg psql -U postgres -d clinica -c "\dt"
```

Você deve ver as tabelas: `patients`, `doctors`, `appointments`, `conversation_state`, `conversation_log`, `followups`, `human_queue`.

### Inserir médicos da sua clínica

```sql
INSERT INTO doctors (name, specialty, registry, google_calendar_id) VALUES
  ('Dr. Carlos Andrade',  'Clínico Geral', 'CRM-SP 123456', 'clinico-geral@clinica.com.br'),
  ('Dra. Beatriz Lima',   'Cardiologia',   'CRM-SP 234567', 'cardio@clinica.com.br');
-- adicione os demais...
```

---

## 4. Configurar Google Calendar

### 4.1. Criar um Calendar por especialidade/médico

Acesse https://calendar.google.com → **+ Criar agenda** → nomeie (ex: "Clínica - Cardiologia") → compartilhe com a conta de serviço (próximo passo).

### 4.2. Criar projeto no Google Cloud

1. https://console.cloud.google.com → **Novo Projeto** → "Clinica Vida N8N"
2. Menu lateral → **APIs e Serviços** → **Biblioteca** → ative **Google Calendar API**
3. **APIs e Serviços** → **Credenciais** → **+ Criar Credenciais** → **Conta de Serviço**
4. Nome: `clinica-n8n` → papel: **Owner** do projeto (ou um papel customizado)
5. Após criada, **Ações** → **Gerenciar chaves** → **Adicionar chave** → **JSON**
6. Salve o JSON baixado como `gcp-service-account.json`

### 4.3. Compartilhar os calendars

Em cada calendar da clínica → **Configurações** → **Compartilhar com pessoas específicas** → adicione o email da conta de serviço (está no JSON, campo `client_email`) → permissão **Fazer alterações em eventos**.

### 4.4. Configurar credencial no n8n

No n8n:
- **Credentials** → **New** → **Google Calendar API**
- **Service Account** → cole o conteúdo do JSON
- Salve

---

## 5. Configurar a Evolution API (WhatsApp)

### 5.1. Criar a instância

```bash
curl -X POST http://localhost:8080/instance/create \
  -H "apikey: sua-chave-aqui" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "clinica",
    "qrcode": true,
    "integration": "WHATSAPP-BAILEYS"
  }'
```

Resposta inclui o **QR Code em base64** + **pairingCode**.

### 5.2. Conectar o WhatsApp

- Abra http://localhost:8080/manager no navegador
- Login com a `apikey`
- Selecione a instância `clinica`
- Clique em **Conectar** → escaneie o QR com o WhatsApp Business da clínica

> **Importante:** use um chip **exclusivo** pra clínica. Se você desvincular, perde o número.

### 5.3. Testar envio

```bash
curl -X POST http://localhost:8080/message/sendText/clinica \
  -H "apikey: sua-chave-aqui" \
  -H "Content-Type: application/json" \
  -d '{"number": "5511999998888", "text": "Teste de conexão 🚀"}'
```

---

## 6. Instalar o n8n

Se você usou Docker Compose, já está rodando em http://localhost:5678.

Caso contrário:

```bash
npm install -g n8n
n8n start
```

Acesse http://localhost:5678 → crie sua conta admin.

---

## 7. Importar os workflows

Pra cada arquivo em `workflows/`:

1. No n8n → **Workflows** → **+ New**
2. Canto superior direito → 3 pontinhos → **Import from File**
3. Selecione o `.json`
4. Salve

Importe na ordem:

1. `01-orchestrator-main.json`
2. `02-booking-flow.json`
3. `03-cancel-reschedule.json`
4. `04-reminders.json`
5. `05-ai-faq-feedback.json`

---

## 8. Configurar credenciais no n8n

### Postgres

- **Credentials** → **New** → **Postgres**
- Host: `postgres` (ou `localhost` se instalar fora do Docker)
- Database: `clinica`
- User: `postgres`
- Password: `clinica123`
- Port: `5432`
- SSL: `disable` (ambiente local)

### Google Calendar OAuth2

Já mostrado no passo 4. Crie UMA credencial e use em todos os nós Google Calendar.

### Evolution API (Header Auth)

- **Credentials** → **New** → **Header Auth**
- Name: `Evolution API Key`
- Header Name: `apikey`
- Header Value: `sua-chave-aqui`

### Variáveis de ambiente

Em **Settings** (canto inferior esquerdo) → **Variables**:

```
EVO_HOST=evo                  # hostname do container, ou localhost
EVO_INSTANCE=clinica
EVO_APIKEY=sua-chave-aqui
OPENAI_API_KEY=sk-...         # opcional
```

---

## 9. Apontar webhook Evolution → n8n

### 9.1. Ativar todos os webhooks

Em cada workflow importado, no nó **Webhook**, ative o workflow (toggle superior direito → verde).

Anote as URLs geradas. Ex:

```
01: https://n8n.clinicavida.com.br/webhook/clinica-webhook
02: https://n8n.clinicavida.com.br/webhook/clinica-booking
03: https://n8n.clinicavida.com.br/webhook/clinica-cancel
03: https://n8n.clinicavida.com.br/webhook/clinica-reschedule
05: https://n8n.clinicavida.com.br/webhook/clinica-ai-faq
```

### 9.2. Configurar na Evolution

No Manager → instância `clinica` → **Webhooks**:

```
URL: https://n8n.clinicavida.com.br/webhook/clinica-webhook
Eventos:
  ✓ messages.upsert
  ✗ messages.update (desligado pra evitar loop)
  ✗ messages.delete
  ✓ connection.update (pra detectar queda)
```

---

## 10. Testar end-to-end

### Checklist

- [ ] Mandar "oi" pro WhatsApp da clínica → recebe menu
- [ ] Escolher 1 (Agendar) → responde pedindo especialidade
- [ ] Responder 2 (Cardiologia) → mostra horários disponíveis
- [ ] Escolher horário → recebe confirmação com ID do evento
- [ ] Conferir Google Calendar → evento criado
- [ ] Conferir banco: `SELECT * FROM appointments ORDER BY created_at DESC LIMIT 1;`
- [ ] Escolher 3 (Cancelar) → lista e cancela
- [ ] Esperar 24h antes da consulta (ou ajustar DB pra teste) → recebe lembrete

### Teste rápido de lembrete

Pra testar sem esperar 24h:

```sql
-- Ajusta pra daqui a 23h e 1h pra cair nas janelas
UPDATE appointments SET start_time = NOW() + INTERVAL '23 hours 30 minutes' WHERE id = '...';
UPDATE appointments SET start_time = NOW() + INTERVAL '1 hour 45 minutes' WHERE id = '...';

-- Marca como ainda não enviado
UPDATE appointments SET reminder_24h_sent = false, reminder_2h_sent = false WHERE id = '...';
```

Depois rode o workflow 04 manualmente (botão **Execute Workflow**).

---

## 11. Colocar em produção

### Checklist de produção

- [ ] **HTTPS obrigatório** — use Caddy, Traefik ou Cloudflare Tunnel (nunca HTTP puro em produção!)
- [ ] **Domínio próprio** configurado
- [ ] **Backup automático** do PostgreSQL (cron + pg_dump)
- [ ] **Monitoramento**: UptimeRobot no healthcheck `/healthz`
- [ ] **Logs centralizados** (Loki, Datadog ou ELK)
- [ ] **Rate limiting** na frente do n8n (Cloudflare WAF funciona bem)
- [ ] **Alerta de quota** OpenAI (se usar IA)
- [ ] **Política de privacidade** publicada (LGPD)
- [ ] **Termo de consentimento** no primeiro contato do bot
- [ ] **Plano de contingência**: chip reserva + número de telefone fixo

### Cloudflare Tunnel (recomendado, sem expor porta)

```bash
# Instale cloudflared
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared focal main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared

# Login
cloudflared tunnel login

# Criar tunnel
cloudflared tunnel create clinica-n8n
cloudflared tunnel route dns clinica-n8n atendimento.clinicavida.com.br

# Config
cat > ~/.cloudflared/config.yml <<EOF
tunnel: clinica-n8n
credentials-file: /home/ubuntu/.cloudflared/<UUID>.json

ingress:
  - hostname: atendimento.clinicavida.com.br
    service: http://localhost:5678
  - service: http_status:404
EOF

# Rodar
cloudflared tunnel run clinica-n8n
```

Pronto — seu n8n está em HTTPS sem precisar abrir porta 443.

### Backup automático do banco

```bash
# Adiciona no crontab
0 3 * * * docker exec clinica-pg pg_dump -U postgres clinica | gzip > /backups/clinica-$(date +\%Y\%m\%d).sql.gz

# Mantém só últimos 30
0 4 * * * find /backups -name "clinica-*.sql.gz" -mtime +30 -delete
```

---

## 🆘 Problemas comuns

### Bot não responde

```bash
# 1. Checar webhook
docker logs clinica-evo | grep webhook
docker logs clinica-n8n | grep "Webhook Evolution API"

# 2. Checar se a Evolution está conectada
curl http://localhost:8080/instance/connectionState/clinica \
  -H "apikey: sua-chave"
```

### Mensagens duplicadas

- A Evolution às vezes envia duplicado em reconexão
- No workflow 01, use o nó **Redis** ou **Postgres** com INSERT IGNORE pra deduplicar por `messageId`

### Google Calendar retorna 404

```bash
# Verifique se a service account tem acesso ao calendar
gcloud auth activate-service-account --key-file=gcp-service-account.json
gcloud calendar acl list primary
```

### Custos inesperados de IA

- Limite o `max_tokens` (já está em 400 — OK)
- Configure **alerta de billing** em platform.openai.com pra $20
- Use cache de respostas repetidas (Redis) se necessário

---

Mais dúvidas? Abre issue no GitHub ou me chama no direct 😊
