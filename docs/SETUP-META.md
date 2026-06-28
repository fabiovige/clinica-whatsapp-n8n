# 🌐 Setup com Meta WhatsApp Cloud API (API Oficial)

> Guia completo pra usar a **API oficial** da Meta ao invés da Evolution.
> É mais profissional, oficial, mas exige aprovação de templates.

---

## 📊 Comparação: Evolution vs Meta Oficial

| | Evolution API | Meta Cloud API |
|---|---|---|
| **Custo** | Grátis | 1.000 conversas grátis/mês + US$ 0,0025-0,015 por msg* |
| **Setup** | Escaneia QR | Precisa aprovar Facebook Business |
| **Templates** | Não precisa | Precisa aprovar cada template (24-48h) |
| **Estabilidade** | Depende do WhatsApp Web | Oficial, estável |
| **Risco de ban** | Médio (quebra ToS) | Zero (oficial) |
| **Marca verificada** | Não | Sim, com selo azul (opcional) |
| **Múltiplos números** | Sim, com multi-device | 1 número por app (multi-app pra escalar) |
| **Suporte** | Comunidade | Meta direto |

*\* Meta cobra por "conversa de serviço" (24h) e "marketing" (template).*

**Recomendação:**
- Clínica nova, sem infra → comece com **Evolution** pra validar
- Clínica estabelecida, quer oficializar → **Meta API**

---

## 1. Pré-requisitos

- ✅ Servidor Linux Mint/Debian com Docker instalado (use `scripts/install-linux-mint.sh`)
- ✅ Domínio próprio com DNS apontado (HTTPS é **obrigatório**)
- ✅ Conta Facebook pessoal (pra ser admin do Business Manager)
- ✅ CNPJ ou CPF da clínica (pra verificação de negócio — opcional mas recomendado)

---

## 2. Criar Facebook Business Manager

1. Acesse https://business.facebook.com
2. **Criar conta** → preencha com dados da clínica
3. Confirme o email

---

## 3. Criar App no Meta Developers

1. Acesse https://developers.facebook.com/apps
2. **Criar App** → tipo **Business** → nome: "Clínica Vida WhatsApp"
3. Em **Adicionar produtos**, clique em **WhatsApp** → **Configurar**
4. Você vai ver:
   - **Phone Number ID** → salve (`META_PHONE_ID`)
   - **WhatsApp Business Account ID** → salve
   - **Temporary access token** → salve (`META_TOKEN` temporário)

---

## 4. Adicionar número de WhatsApp

### 4.1. Opção A — Usar número de teste (grátis, pra desenvolvimento)

A Meta dá 5 números de teste (não recebe mensagens reais, só dos números autorizados).

1. No painel do App → WhatsApp → **API Setup**
2. Em **Step 1**, escolha um número de teste ou adicione o seu
3. **Adicione seu número** aos números que podem receber teste (meta registra seu WhatsApp)
4. Use o token temporário por enquanto

### 4.2. Opção B — Número real da clínica (produção)

1. **WhatsApp Manager** (https://business.facebook.com/wa/manage/home) → **Configurações** → **Contas do WhatsApp Business** → **Adicionar**
2. Siga o fluxo de verificação por SMS/ligação
3. Escolha o **display name** (nome que aparece pro cliente) — geralmente o nome da clínica
4. Após aprovação (1-7 dias), o número tá pronto pra uso real

---

## 5. Configurar Webhook

### 5.1. Pegue sua URL HTTPS pública

```bash
# Após subir o docker-compose, seu n8n tá em:
https://atendimento.SEU_DOMINIO.com.br

# A URL do webhook é:
https://atendimento.SEU_DOMINIO.com.br/webhook/clinica-meta-webhook
```

⚠️ **O webhook TEM que ser HTTPS válido.** Não funciona com IP, nem HTTP.

### 5.2. Configure no painel da Meta

1. **developers.facebook.com** → seu app → **WhatsApp** → **Configuration**
2. Seção **Webhook** → **Edit**
3. Preencha:
   - **Callback URL**: `https://atendimento.SEU_DOMINIO.com.br/webhook/clinica-meta-webhook`
   - **Verify Token**: o mesmo que você colocou em `META_VERIFY_TOKEN` no `.env`
4. **Verify and Save** → a Meta faz GET no seu endpoint pra confirmar

### 5.3. Inscreva nos eventos

Em **Webhook fields**, marque:

- ✅ `messages` — mensagens recebidas
- ✅ `message_echoes` — mensagens que você envia (útil pra debug)
- ✅ `message_template_status_update` — status de aprovação de template
- ✅ `smb_message_echoes` — eco de mensagens em conversa business-initiated

### 5.4. Script automático

Ou use o script:

```bash
./scripts/setup-meta-webhook.sh \
  https://atendimento.clinicavida.com.br \
  seu-verify-token-aqui \
  1234567890123456 \
  EAAxxxxxx...
```

---

## 6. Criar e aprovar Templates

Templates são mensagens pré-aprovadas que você pode enviar a qualquer momento.
**Lembretes precisam ser templates** (não dá pra mandar mensagem livre depois de 24h).

### Como submeter um template

1. **business.facebook.com/wa/manage/message-templates** → **Criar modelo**
2. Categoria: **Utility** (lembretes, confirmação) ou **Marketing** (promoções)
3. Idioma: **Português (BR)**
4. Preencha o conteúdo
5. Submeta pra revisão (geralmente 24-48h)

### Templates que você PRECISA criar

#### Template 1: `consulta_confirmada`
**Quando:** logo após o paciente agendar
**Categoria:** Utility

```
Olá, {{1}}! 👋

Sua consulta na Clínica Vida está confirmada:

📋 Especialidade: {{2}}
📅 Data: {{3}}
⏰ Horário: {{4}}

Você receberá lembretes 24h e 2h antes da consulta.

Para cancelar: responda CANCELAR
Para remarcar: responda REMARCAR

Até logo! 💚
```

**Variáveis:**
- `{{1}}` = primeiro nome do paciente
- `{{2}}` = especialidade
- `{{3}}` = data por extenso
- `{{4}}` = hora

Botão opcional (URL): "📍 Ver no mapa" → link Google Maps

---

#### Template 2: `lembrete_24h`
**Quando:** 24h antes da consulta
**Categoria:** Utility (utility tem custo menor)

```
Oi, {{1}}! 👋

Lembrete: sua consulta é AMANHÃ!

📋 {{2}}
📅 {{3}}

✅ Confirma presença?
- Responda SIM para confirmar
- Responda REAGENDAR se precisar mudar
- Responda CANCELAR se não puder ir

Até logo! 💚
```

**Variáveis:**
- `{{1}}` = primeiro nome
- `{{2}}` = especialidade
- `{{3}}` = data por extenso

Botões de resposta rápida (Quick Reply):
- "✅ Confirmo"
- "🔄 Reagendar"
- "❌ Cancelar"

---

#### Template 3: `lembrete_2h`
**Quando:** 2h antes da consulta
**Categoria:** Utility

```
⏰ {{1}}, sua consulta é em 2 HORAS!

📋 {{2}}
⏰ {{3}}
📍 Clínica Vida — Rua das Flores, 123

Não esqueça de trazer:
• Documento com foto
• Carteirinha do convênio
• Exames anteriores (se tiver)

Até já! 😊
```

**Variáveis:**
- `{{1}}` = primeiro nome
- `{{2}}` = especialidade
- `{{3}}` = hora

---

#### Template 4: `feedback_pos_consulta`
**Quando:** 6h depois da consulta
**Categoria:** Marketing (ou utility, depende do objetivo)

```
Olá, {{1}}! 😊

Esperamos que sua consulta de {{2}} tenha sido ótima!

Pode nos dar uma avaliação rápida? Leva 10 segundos!

⭐⭐⭐⭐⭐ Responda com um número de 1 a 5.

Sua opinião nos ajuda a melhorar! 💚
```

**Variáveis:**
- `{{1}}` = primeiro nome
- `{{2}}` = especialidade

---

#### Template 5: `consulta_cancelada` (opcional)
**Quando:** após cancelamento
**Categoria:** Utility

```
{{1}}, sua consulta foi cancelada.

📋 {{2}}
📅 {{3}}

O horário foi liberado. Quando quiser agendar de novo, é só nos chamar por aqui.

Cuide-se! 💚
```

---

### Como usar o header com imagem (opcional)

Você pode adicionar header com imagem nos templates:

1. No editor do template → **Add media** → **Image**
2. Faça upload de uma imagem (logo, mascote, etc)
3. Após aprovação, envie com:

```json
{
  "type": "template",
  "template": {
    "name": "consulta_confirmada",
    "language": {"code": "pt_BR"},
    "components": [
      {
        "type": "header",
        "parameters": [
          {"type": "image", "image": {"link": "https://clinica.com.br/logo.png"}}
        ]
      },
      {
        "type": "body",
        "parameters": [...]
      }
    ]
  }
}
```

---

## 7. Atualizar workflows n8n com IDs reais

Depois de aprovados os templates, anote os **nomes exatos** (case-sensitive!) que a Meta retornar. Os workflows já estão configurados pra usar esses nomes — basta ajustar se você usou nomes diferentes.

No workflow `04-meta-reminders.json`, nó **"Envia template 24h"**, edite:

```json
"name": "lembrete_24h",     ← use o nome exato aprovado
```

---

## 8. Token permanente (System User Token)

O token temporário expira em **24 horas**. Pra produção:

### 8.1. Criar System User

1. **business.facebook.com/settings/system-users** → **Adicionar**
2. Nome: `clinica-n8n-bot`
3. Função: **Admin**
4. Atribua o **App** "Clínica Vida WhatsApp" e o **WhatsApp Business Account**

### 8.2. Gerar token permanente

1. System User → **Gerar token**
2. App: **Clínica Vida WhatsApp**
3. Permissões:
   - ✅ `whatsapp_business_management`
   - ✅ `whatsapp_business_messaging`
4. Expira em: **Nunca**
5. **Gerar** → **copie o token** (só aparece uma vez!)

### 8.3. Atualizar `.env`

```bash
META_TOKEN=EAAB...seu-token-permanente-aqui...
```

Reinicie o n8n:

```bash
docker compose restart n8n
```

---

## 9. Custos e cobrança

### Modelo de cobrança da Meta

| Tipo de conversa | Quem inicia | Janela | Custo* |
|---|---|---|---|
| **Service** (utilidade, confirmação) | Business | 24h | Grátis (até 1.000/mês) |
| **Marketing** (promo, feedback) | Business | 24h | US$ 0,015 por conversa |
| **Utility** (lembrete) | Business | 24h | US$ 0,0025 por conversa |

*\* Preços variam por país. Brasil ~US$ 0,0025-0,015. Veja tabela atual em https://developers.facebook.com/docs/whatsapp/pricing*

### Estimativa pra clínica média

Cenário: 500 consultas/mês, 2 lembretes cada, 30% respondem com feedback

```
500 confirmações       → 500 conversas service   → R$ 0 (até 1.000 grátis)
1.000 lembretes        → 1.000 conversas utility → ~R$ 12,50
150 feedbacks          → 150 conversas marketing → ~R$ 11,25
                                            Total: ~R$ 24/mês
```

Bem acessível. Aumenta se você usar muito marketing.

### Monitorar gasto

1. **business.facebook.com/wa/manage/billing** → mostra gastos
2. Configure **alerta de billing** em US$ 50/mês (por segurança)
3. Adicione cartão de crédito internacional

---

## 10. Limites e quotas

| Limite | Valor |
|---|---|
| Throughput | 80 msg/segundo (limite padrão) |
| Phone number quality rating | Afeta o limite (verde = alto, amarelo = médio, vermelho = bloqueado) |
| Mensagens por dia por usuário | Sem limite, mas Meta avalia qualidade |
| Tamanho máx. de mídia | 16 MB (imagem), 16 MB (vídeo), 16 MB (doc), 1 MB (audio) |

### Como manter o "quality rating" alto

- ✅ Responda rápido (use os workflows!)
- ✅ Use **templates aprovados** (nunca mande msg livre depois de 24h)
- ✅ Personalize os templates (use {{1}} com nome do paciente)
- ✅ Dê opção de opt-out ("Responda SAIR pra não receber mais")
- ❌ Nunca mande spam
- ❌ Nunca envie msg sem ser solicitada depois de 24h

---

## 11. Status dos webhooks

Após configurar, monitore em tempo real:

1. **developers.facebook.com** → seu app → **WhatsApp** → **Configuration**
2. Em **Webhook**, veja:
   - ✅ Verde = ativo e recebendo
   - ⚠️ Amarelo = atrasado
   - ❌ Vermelho = não está respondendo

**Se ficar vermelho**, verifique:

```bash
# 1. Caddy tá servindo o webhook?
curl -I https://atendimento.SEU_DOMINIO.com.br/webhook/clinica-meta-webhook

# 2. n8n tá rodando?
docker compose ps n8n
docker compose logs n8n | grep -i webhook

# 3. Workflow 01-META tá ativo?
# Acesse o n8n, toggle verde no canto superior direito
```

---

## 12. Testando

### 12.1. Mensagem do paciente

1. Abra o WhatsApp no celular (com o número que você usou pra cadastrar)
2. Mande "oi" pro número da clínica
3. Resposta deve vir em ~2 segundos

### 12.2. Mensagem livre (24h window)

Quando o paciente mandou msg, você tem 24h pra mandar mensagens livres (texto puro, botões, listas).

### 12.3. Template (fora da janela)

Lembretes 24h e 2h antes usam templates. Teste forçando uma consulta no DB:

```sql
-- Cria consulta pra daqui a 23h
INSERT INTO appointments (phone, patient_name, specialty, doctor, start_time, end_time, status)
VALUES ('5511999998888', 'João Teste', 'Cardiologia', 'Dra. Beatriz',
        NOW() + INTERVAL '23 hours 30 minutes',
        NOW() + INTERVAL '24 hours 10 minutes',
        'confirmed');

-- Roda o workflow 04 manualmente (botão "Execute Workflow")
```

### 12.4. Verificar logs

```bash
docker compose logs -f n8n | grep -E "(meta|whatsapp|graph)"
```

---

## 13. Troubleshooting

### Webhook não verifica

```
Erro: "Callback verification failed"
```

→ Confirme que `META_VERIFY_TOKEN` no `.env` é **exatamente** o mesmo configurado na Meta

```bash
# Checar se tá respondendo o challenge certo:
curl "https://atendimento.SEU_DOMINIO.com.br/webhook/clinica-meta-webhook?hub.mode=subscribe&hub.verify_token=SEU_TOKEN&hub.challenge=12345"
# Deve retornar: 12345
```

### Mensagens não chegam

```
1. Webhook tá verde no painel Meta?
2. Token expirou? (gera novo)
3. Phone Number ID correto?
4. n8n tá rodando? (docker compose ps)
5. Firewall tá bloqueando? (curl do servidor)
```

### Template rejeitado

Motivos comuns:
- Variáveis sem exemplo (Meta exige exemplo de cada {{1}}, {{2}})
- Categoria errada (lembrete não pode ser marketing sem CTA claro)
- Conteúdo vago ou ambíguo

Reaplique com ajustes.

### "Rate limit hit"

```
{ "error": { "code": 130429, "message": "Rate limit hit" } }
```

→ Você mandou muitas mensagens rápido. Solução:
- Distribua envios ao longo do dia (n8n pode fazer com `Wait` node)
- Solicite aumento de quota à Meta (suporte premium)

---

## 14. Migração Evolution → Meta

Se você já tinha Evolution rodando e quer migrar pra Meta:

1. ✅ Coloque o Meta pra rodar em paralelo (ambos usam o mesmo DB)
2. ✅ Migre os pacientes existentes (já estão no DB, basta o telefone)
3. ✅ Atualize o `phoneNumberId` no workflow se necessário
4. ✅ Mantenha Evolution como fallback durante 30 dias
5. ✅ Após confirmar que Meta funciona bem, desligue Evolution

---

## Próximo passo

Tudo configurado? Próximo:
- [Personalizar templates](https://business.facebook.com/wa/manage/message-templates)
- [Configurar fluxos no Meta Inbox](https://business.facebook.com/latest/inbox)
- [Adicionar mais médicos no banco](../database/schema.sql)
- [Coletar feedback dos pacientes](FLUXO_CONVERSA.md)

Dúvidas? 👇
