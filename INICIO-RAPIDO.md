# 🚀 INÍCIO RÁPIDO · Clínica WhatsApp

> 3 passos pra colocar o sistema no ar.

---

## 1️⃣ Instalar Docker (Linux Mint / Debian 13)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git
chmod +x scripts/install-linux-mint.sh
sudo ./scripts/install-linux-mint.sh
```

> Faz logout/login depois (pra o grupo docker funcionar).

## 2️⃣ Configurar

```bash
# Copie o projeto pra sua home (se ainda não estiver lá)
cd ~/clinica-whatsapp-n8n

# Edite o .env com seus dados
cp .env.example .env
nano .env

# Ajuste o domínio no Caddyfile
nano caddy/Caddyfile
# Trocar SEU_DOMINIO pelo seu domínio real
```

## 3️⃣ Subir

```bash
docker compose up -d
docker compose logs -f n8n
```

Aguarde 30 segundos, então acesse: **https://atendimento.seu-dominio.com.br**

---

## 📋 Qual API de WhatsApp usar?

| Situação | Escolha |
|---|---|
| Testar agora (sem burocracia) | **Evolution API** (QR Code) |
| Produção oficial / escala | **Meta Cloud API** (requer aprovação de templates) |

Os workflows estão numerados:

| Versão Evolution | Versão Meta |
|---|---|
| `01-orchestrator-main.json` | `01-meta-orchestrator.json` |
| `02-booking-flow.json` | `02-meta-booking.json` |
| `03-cancel-reschedule.json` | (use o mesmo) |
| `04-reminders.json` | `04-meta-reminders.json` |
| `05-ai-faq-feedback.json` | (use o mesmo) |

Importe no n8n apenas os que for usar.

---

## 📚 Documentação

- **`README.md`** — visão geral + features
- **`ARQUITETURA.md`** — detalhes técnicos
- **`docs/SETUP.md`** — setup completo (Evolution)
- **`docs/SETUP-META.md`** — setup completo (Meta oficial)
- **`docs/META-TEMPLATES.md`** — templates prontos pra Meta
- **`docs/FLUXO_CONVERSA.md`** — roteiros de conversa do bot

---

## 🆘 Ajuda rápida

**Bot não responde?**
```bash
docker compose logs -f n8n | grep -i webhook
docker compose ps
```

**Ver banco?**
```bash
docker exec -it clinica-postgres psql -U postgres -d clinica
\dt          # lista tabelas
SELECT * FROM appointments LIMIT 10;
```

**Reiniciar tudo?**
```bash
docker compose restart
```

**Apagar tudo e começar do zero?**
```bash
docker compose down -v
docker compose up -d
```

---

**Custo estimado:** R$ 80–250/mês (servidor + Google Workspace + opcional OpenAI)

Sucesso! 💚
