# 📋 Templates Meta · Prontos pra copiar/colar

> Cole esses templates no painel **business.facebook.com/wa/manage/message-templates**.
> Mantenha os nomes EXATAMENTE iguais aos usados nos workflows n8n.

---

## Índice

1. [`consulta_confirmada`](#1-consulta_confirmada)
2. [`lembrete_24h`](#2-lembrete_24h)
3. [`lembrete_2h`](#3-lembrete_2h)
4. [`feedback_pos_consulta`](#4-feedback_pos_consulta)
5. [`consulta_cancelada`](#5-consulta_cancelada)
6. [`consulta_remarcada`](#6-consulta_remarcada)

---

## ⚠️ Regras importantes

- **Variáveis** = `{{1}}`, `{{2}}` etc — não use `{{nome}}` nem nomes descritivos
- Cada variável precisa de **exemplo** na hora de submeter (ex: `João`, `Cardiologia`)
- **Botões de resposta rápida** = até 3 botões, texto curto
- **Botão de URL** = até 2, link válido e público
- Categoria certa (lembrete não pode ser "marketing")

---

## 1. `consulta_confirmada`

**Categoria:** `Utility`
**Idioma:** `pt_BR`
**Header:** (opcional) Texto: "✅ Consulta Confirmada"

### Body

```
Olá, {{1}}! 👋

Sua consulta na *Clínica Vida* está confirmada:

📋 Especialidade: {{2}}
📅 Data: {{3}}
⏰ Horário: {{4}}

Você receberá lembretes 24h e 2h antes.

Para *cancelar*: responda CANCELAR
Para *remarcar*: responda REMARCAR

Até logo! 💚
```

### Footer (opcional)

```
Clínica Vida · (11) 3333-4444
```

### Botões

| Tipo | Texto | Ação |
|---|---|---|
| URL | 📍 Como chegar | https://maps.google.com/?q=Rua+das+Flores+123 |
| Quick Reply | ✅ Confirmar | — |
| Quick Reply | 🔄 Remarcar | — |

### Exemplos das variáveis (preencher ao submeter)

| Var | Exemplo |
|---|---|
| `{{1}}` | João |
| `{{2}}` | Cardiologia |
| `{{3}}` | sábado, 28 de junho |
| `{{4}}` | 10:40 |

---

## 2. `lembrete_24h`

**Categoria:** `Utility`
**Idioma:** `pt_BR`

### Body

```
Oi, {{1}}! 👋

Lembrete: sua consulta é *AMANHÃ*!

📋 {{2}}
📅 {{3}}

✅ Confirma presença?
```

### Footer

```
Responda com um dos botões abaixo
```

### Botões

| Tipo | Texto |
|---|---|
| Quick Reply | ✅ Confirmo |
| Quick Reply | 🔄 Reagendar |
| Quick Reply | ❌ Cancelar |

### Exemplos

| Var | Exemplo |
|---|---|
| `{{1}}` | Maria |
| `{{2}}` | Cardiologia |
| `{{3}}` | sábado, 28 de junho |

---

## 3. `lembrete_2h`

**Categoria:** `Utility`
**Idioma:** `pt_BR`

### Body

```
⏰ {{1}}, sua consulta é em *2 HORAS*!

📋 {{2}}
⏰ {{3}}
📍 Clínica Vida — Rua das Flores, 123

Não esqueça de trazer:
• Documento com foto
• Carteirinha do convênio
• Exames anteriores
```

### Botões

| Tipo | Texto | Ação |
|---|---|---|
| URL | 📍 Ver mapa | https://maps.google.com/?q=Rua+das+Flores+123 |

---

## 4. `feedback_pos_consulta`

**Categoria:** `Marketing` (ou `Utility` se preferir)
**Idioma:** `pt_BR`

### Body

```
Olá, {{1}}! 😊

Esperamos que sua consulta de *{{2}}* tenha sido ótima!

Pode nos dar uma avaliação rápida? Leva 10 segundos!

⭐ Responda com um número de 1 a 5.
```

### Botões

| Tipo | Texto |
|---|---|
| Quick Reply | ⭐ 1 |
| Quick Reply | ⭐⭐ 2 |
| Quick Reply | ⭐⭐⭐ 3 |
| Quick Reply | ⭐⭐⭐⭐ 4 |
| Quick Reply | ⭐⭐⭐⭐⭐ 5 |

⚠️ Quick Reply limita a 3 botões. Use Quick Reply + "Ver mais" → lista, ou só os 3 mais importantes.

---

## 5. `consulta_cancelada`

**Categoria:** `Utility`
**Idioma:** `pt_BR`

### Body

```
{{1}}, sua consulta foi cancelada. ❌

📋 {{2}}
📅 {{3}}

O horário foi liberado. Quando quiser agendar de novo, é só nos chamar por aqui.

Cuide-se! 💚
```

---

## 6. `consulta_remarcada`

**Categoria:** `Utility`
**Idioma:** `pt_BR`

### Body

```
🔄 {{1}}, sua consulta foi *remarcada*!

De:
📋 {{2}}
📅 {{3}}

Para:
📋 {{4}}
📅 {{5}}

Os lembretes foram atualizados. Até logo! 💚
```

---

## 7. `boas_vindas` (opcional)

**Categoria:** `Marketing`
**Idioma:** `pt_BR`

### Body

```
Bem-vindo(a) à *Clínica Vida*, {{1}}! 💚

Somos uma clínica completa com:
✅ 6 especialidades médicas
✅ Convênios: Unimed, Amil, SulAmérica, Bradesco
✅ Agendamento fácil pelo WhatsApp

Para *agendar*, responda AGENDAR
Para *informações*, responda INFO

Estamos aqui pra cuidar de você! 😊
```

---

## Como submeter em lote

Você pode submeter todos via API também:

```bash
curl -X POST \
  "https://graph.facebook.com/v21.0/{WABA-ID}/message_templates" \
  -H "Authorization: Bearer SEU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "consulta_confirmada",
    "category": "UTILITY",
    "language": "pt_BR",
    "components": [
      {
        "type": "BODY",
        "text": "Olá, {{1}}! 👋\n\nSua consulta na *Clínica Vida* está confirmada:\n\n📋 Especialidade: {{2}}\n📅 Data: {{3}}\n⏰ Horário: {{4}}\n\nAté logo! 💚",
        "example": {
          "body_text": [
            ["João", "Cardiologia", "sábado, 28 de junho", "10:40"]
          ]
        }
      }
    ]
  }'
```

---

## Status de aprovação

Após submeter, em **~24h** os templates ficam:

- ✅ **APPROVED** — pode usar
- ❌ **REJECTED** — ver motivo, ajustar e resubmeter
- ⏳ **PENDING** — aguardando revisão

Acompanhe em **business.facebook.com/wa/manage/message-templates**.

---

## Substituindo variáveis no n8n

No workflow `04-meta-reminders.json` → nó **"Envia template 24h"**:

```json
{
  "template": {
    "name": "lembrete_24h",   ← nome EXATO do template aprovado
    "language": {"code": "pt_BR"},
    "components": [
      {
        "type": "body",
        "parameters": [
          {"type": "text", "text": "{{ $json.firstName }}"},     ← {{1}}
          {"type": "text", "text": "{{ $json.specialty }}"},     ← {{2}}
          {"type": "text", "text": "{{ $json.date }}"}           ← {{3}}
        ]
      }
    ]
  }
}
```

A ordem importa: `{{1}}` recebe `firstName`, `{{2}}` recebe `specialty`, etc.

---

## Política da Meta pra templates

✅ **Permitido:**
- Confirmações, lembretes, atualizações de agendamento
- Feedback e pesquisa de satisfação
- Notificações de resultado de exame
- Promoções com opt-in

❌ **Proibido:**
- Spam ou conteúdo enganoso
- Conteúdo ilegal
- Sem variável quando necessário (pra personalizar)
- Linguagem ameaçadora

❓ **Revisão especial (utility):**
- Templates sem CTA (call-to-action) precisam ser Marketing
- Templates com horário/data precisam ter janela de 24h de antecedência

---

## Próximos templates a criar

Conforme sua clínica crescer, considere adicionar:

- `exame_resultado_disponivel` — quando exame fica pronto
- `receita_digital` — link pra baixar receita
- `aniversario_paciente` — Marketing
- `campanha_vacina` — Marketing sazonal
- `follow_up_pos_cirurgia` — pós-procedimento
- `aviso_feriado` — mudanças de horário
