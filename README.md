# 🏥 Clínica WhatsApp · Atendimento Automatizado

Sistema completo de atendimento via **WhatsApp** para clínicas médicas, integrado com **n8n** e **Google Calendar**.

> Stack: Evolution API · n8n · PostgreSQL · Google Calendar · OpenAI (opcional)

---

## ✨ O que esse sistema faz

- 📅 **Agenda consultas** automaticamente no Google Calendar (verifica conflitos em tempo real)
- ❌ **Cancela e remarca** sem precisar de atendente humano
- ⏰ **Envia lembretes** 24h e 2h antes da consulta (reduz no-show em até 60%)
- 🤖 **Atende FAQ** sobre endereço, convênios, preparo de exames — com IA opcional
- 👩‍💼 **Transfere para humano** quando o paciente pedir ou quando a IA não souber responder
- 📊 **Coleta feedback** (1-5 estrelas) depois de cada consulta
- 📋 **Registra tudo** num banco PostgreSQL para auditoria e relatórios
- 🧠 **Mantém contexto** da conversa (state machine) — o paciente pode pausar e voltar

---

## 🧩 Componentes

| # | Workflow | Função |
|---|----------|--------|
| 01 | `01-orchestrator-main.json` | Recebe mensagens do WhatsApp, detecta intenção, roteia |
| 02 | `02-booking-flow.json` | Cria evento no Google Calendar + salva no DB |
| 03 | `03-cancel-reschedule.json` | Cancela ou remarca consulta existente |
| 04 | `04-reminders.json` | Cron que dispara lembretes 24h e 2h antes |
| 05 | `05-ai-faq-feedback.json` | IA para FAQ + coleta feedback pós-consulta |

```
clinica-whatsapp-n8n/
├── README.md                       ← você está aqui
├── ARQUITETURA.md                  ← detalhes técnicos
├── diagram/arquitetura.html        ← diagrama visual (abra no browser)
├── workflows/
│   ├── 01-orchestrator-main.json
│   ├── 02-booking-flow.json
│   ├── 03-cancel-reschedule.json
│   ├── 04-reminders.json
│   └── 05-ai-faq-feedback.json
├── database/schema.sql             ← schema PostgreSQL completo
└── docs/
    ├── SETUP.md                    ← passo a passo de instalação
    └── FLUXO_CONVERSA.md           ← roteiros de conversa
```

---

## 🚀 Quick start

### 1. Suba a infra

```bash
# 1) PostgreSQL (banco da clínica)
docker run -d --name clinica-pg \
  -e POSTGRES_PASSWORD=clinica123 \
  -e POSTGRES_DB=clinica \
  -p 5432:5432 \
  postgres:16

# 2) n8n (orquestrador)
docker run -d --name clinica-n8n \
  -e N8N_HOST=localhost \
  -e N8N_PORT=5678 \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=postgres \
  -e DB_POSTGRESDB_DATABASE=n8n \
  -p 5678:5678 \
  n8nio/n8n

# 3) Evolution API (gateway WhatsApp)
docker run -d --name clinica-evo \
  -e AUTHENTICATION_API_KEY=sua-chave-secreta-aqui \
  -p 8080:8080 \
  atendai/evolution-api:latest
```

### 2. Configure o banco

```bash
psql -h localhost -U postgres -d clinica -f database/schema.sql
```

### 3. Importe os workflows

1. Abra o n8n → http://localhost:5678
2. Menu → **Import from File** → selecione cada `.json` da pasta `workflows/`
3. Configure as credenciais:
   - **Postgres** → host `postgres`, db `clinica`, user `postgres`, senha `clinica123`
   - **Google Calendar OAuth2** → conta de serviço da clínica
   - **Header Auth** → header `apikey`, valor a chave da Evolution API

### 4. Configure o WhatsApp

```bash
# Criar instância na Evolution API
curl -X POST http://localhost:8080/instance/create \
  -H "apikey: sua-chave-secreta-aqui" \
  -H "Content-Type: application/json" \
  -d '{"instanceName": "clinica", "qrcode": true}'

# Escanear QR Code com o WhatsApp Business
```

### 5. Configure o webhook

No painel da Evolution (`/manager`), aponte os eventos para o webhook do n8n:

```
Webhook URL: http://n8n:5678/webhook/clinica-webhook
Eventos: messages.upsert
```

### 6. Variáveis de ambiente no n8n

Em **Settings → Variables**:

```
EVO_HOST=evo                # hostname da Evolution
EVO_INSTANCE=clinica
EVO_APIKEY=sua-chave-secreta-aqui
OPENAI_API_KEY=sk-...       # opcional, pra IA
```

### 7. Teste

Mande "oi" pro número do WhatsApp Business configurado. 🎉

---

## 💬 Exemplo de conversa

```
👤 Paciente:  oi

🤖 Bot:   Olá, Maria! 👋
          Sou a assistente virtual da Clínica Vida. Como posso te ajudar hoje?

          1️⃣  Agendar consulta
          2️⃣  Ver meus agendamentos
          3️⃣  Cancelar consulta
          4️⃣  Remarcar consulta
          5️⃣  Informações (endereço, convênios)
          6️⃣  Falar com atendente

          Digite o número da opção

👤 Paciente:  1

🤖 Bot:   Ótimo! Vamos agendar 😊
          Qual especialidade você precisa?
          1️⃣  Clínico Geral
          2️⃣  Cardiologia
          3️⃣  Dermatologia
          ...

👤 Paciente:  2

🤖 Bot:   Que dia fica melhor para você?
          Responda com a data no formato DD/MM
          (ex: 25/06)

👤 Paciente:  28/06

🤖 Bot:   Horários disponíveis para Cardiologia em 28/06:
          • 09:00  • 10:40  • 14:00  • 16:20
          Qual prefere?

👤 Paciente:  10:40

🤖 Bot:   ✅ Consulta agendada com sucesso!
          📋 Cardiologia - Dra. Beatriz Lima
          📅 sábado, 28 de junho
          ⏰ 10:40
          Você receberá lembretes 24h e 2h antes.
          Para cancelar, digite 3.

— 24h antes —

🤖 Bot:   👋 Oi, Maria!
          Lembrete: sua consulta é amanhã!
          📋 Cardiologia
          📅 sábado, 28 de junho
          ⏰ 10:40
          📍 Clínica Vida — Rua das Flores, 123
          ✅ Confirma presença?
          1 — Confirmo   2 — Preciso remarcar   3 — Cancelar

— 2h antes —

🤖 Bot:   ⏰ Daqui a 2 horas você tem consulta!
          📋 Cardiologia · ⏰ 10:40 · 📍 Clínica Vida
          Não esqueça de trazer:
          • Documento com foto
          • Carteirinha do convênio
          • Exames anteriores (se tiver)
          Até já! 😊

— 6h depois da consulta —

🤖 Bot:   Olá, Maria! 😊
          Esperamos que sua consulta de Cardiologia tenha sido ótima!
          Poderia nos dar uma avaliação rápida?
          ⭐ 1 — Péssimo
          ⭐⭐ 2 — Ruim
          ⭐⭐⭐ 3 — Regular
          ⭐⭐⭐⭐ 4 — Bom
          ⭐⭐⭐⭐⭐ 5 — Excelente
```

---

## 💰 Custo estimado

| Componente | Custo |
|---|---|
| Evolution API (self-hosted) | R$ 0 |
| n8n (self-hosted) | R$ 0 |
| PostgreSQL | R$ 0–100/mês (Hetzner/Contabo) |
| Google Workspace | R$ 38/usuário/mês |
| OpenAI (opcional, gpt-4o-mini) | ~R$ 0,50 por 1000 interações |
| **Total médio para clínica pequena-média** | **R$ 80–250/mês** |

Bem mais barato que atendente dedicado e disponível 24/7.

---

## 🔒 Segurança e LGPD

- ✅ Todos os dados sensíveis ficam no **seu** banco PostgreSQL
- ✅ Consentimento LGPD registrado por paciente (`consent_lgpd`)
- ✅ Credenciais nunca em código — sempre em **credenciais do n8n** ou variáveis de ambiente
- ✅ Logs têm retenção configurável (recomendado: 12 meses)
- ⚠️ Áudio/imagem não são processados por padrão (adicione nó de transcrição se precisar)
- ⚠️ Para produção, **sempre** coloque HTTPS (Cloudflare Tunnel, Traefik, Caddy)

---

## 🛠️ Customização rápida

### Adicionar nova especialidade

Edite o nó **"Resolve Especialidade + Datas"** no workflow 02 e adicione:

```js
'7': { name: 'Nutrição', duration: 30, calendarId: 'nutri@clinica.com.br' }
```

### Mudar horários de atendimento

Edite o `SPECIALTIES` no workflow 02. Para regras mais avançadas (ex: horário só de manhã), use o nó **Code** antes da checagem de disponibilidade.

### Conectar com seu sistema (ERP/HIS)

Os workflows expõem webhooks — você pode chamar de qualquer lugar:

```bash
curl -X POST http://n8n:5678/webhook/clinica-booking \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "5511999998888",
    "patientName": "João Silva",
    "specialty": "1",
    "doctor": "Dr. Carlos",
    "date": "2026-07-15",
    "time": "14:00",
    "notes": "Primeira consulta"
  }'
```

---

## 🐛 Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| Bot não responde | Webhook não está chegando | Verifique `docker logs clinica-n8n` e Evolution Manager |
| Mensagens duplicadas | Webhook configurado 2x | Tire duplicata no painel da Evolution |
| "Especialidade inválida" | ID fora do range | Atualize mapa no nó Code |
| Erro de permissão Google | OAuth sem permissão calendar | Reautorize a credencial |
| "Horário ocupado" sempre | Calendar errado | Confira `google_calendar_id` em `doctors` |
| IA não entende | OpenAI key inválida/sem crédito | Teste a chave em platform.openai.com |

Mais detalhes em [`docs/SETUP.md`](docs/SETUP.md).

---

## 📈 Próximos passos (ideias)

- [ ] Integrar com **Convida** ou **Doctoralia** para receber leads externos
- [ ] Adicionar **confirmação por chamada de voz** (Twilio) pra casos urgentes
- [ ] **Métricas**: no-show rate, tempo médio de resposta, NPS
- [ ] **Multi-clínica**: roteamento por número de WhatsApp
- [ ] **Painel admin**: React/Vue consumindo API do PostgreSQL
- [ ] **Pagamento antecipado** via Pix (integração Mercado Pago)
- [ ] **Receita digital**: enviar PDF da receita pelo WhatsApp

---

## 📝 Licença

MIT — use à vontade, personalize e contribua.

---

Feito com 💚 pra clínicas brasileiras que querem atendimento moderno sem perder o calor humano.
