# 💬 Fluxos de Conversa · Roteiros do Bot

> Todos os textos que o bot manda. Mantém tom **humano, simpático e direto**.
> Personalize à vontade — só não esqueça de atualizar o nó **"Gera Resposta"** no workflow 01.

---

## Tom de voz

- **Você:** assistente virtual da Clínica Vida (use nome se quiser: "Sou a Vida 🤖")
- **Estilo:** informal mas profissional, primeira pessoa, com emojis pontuais
- **Sempre:** confirme a ação antes de executar, dê feedback do que aconteceu
- **Nunca:** dê diagnósticos, sugira medicamentos, faça piada sobre saúde
- **Quando não souber:** "Deixa eu te passar pra um atendente humano, tá? 👩‍💼"

---

## 1. Saudação inicial

**Quando:** primeira mensagem do paciente OU após 30 minutos de inatividade OU texto não reconhecido

```
Olá, {{nome}}! 👋

Sou a assistente virtual da *Clínica Vida*. Como posso te ajudar hoje?

*1️⃣* Agendar consulta
*2️⃣* Ver meus agendamentos
*3️⃣* Cancelar consulta
*4️⃣* Remarcar consulta
*5️⃣* Informações (endereço, convênios)
*6️⃣* Falar com atendente

_Digite o número da opção_
```

---

## 2. Agendar consulta (fluxo principal)

### Passo 1 — Escolha da especialidade

```
Ótimo! Vamos agendar 😊

Qual especialidade você precisa?

*1️⃣* Clínico Geral
*2️⃣* Cardiologia
*3️⃣* Dermatologia
*4️⃣* Ginecologia
*5️⃣* Pediatria
*6️⃣* Ortopedia

Responde com o número da especialidade.
```

### Passo 2 — Escolha da data

```
Para *{{especialidade}}*, qual dia fica melhor?

Responda no formato *DD/MM*
(ex: 25/06)

Ou digite *hoje* / *amanhã* se preferir.
```

### Passo 3 — Escolha do horário

```
Horários disponíveis para *{{especialidade}}* em {{data}}:

⏰ *09:00*
⏰ *10:40*
⏰ *14:00*
⏰ *16:20*

Qual prefere? Responde só a hora (ex: 14:00)
```

> Os horários vêm do Google Calendar — o n8n filtra os slots livres de 30 em 30 min no expediente do médico.

### Passo 4 — Confirmação

```
Vou confirmar os dados, ok? 📋

*Especialidade:* {{especialidade}}
*Profissional:* Dr(a). {{nome_do_medico}}
*Data:* {{data_extenso}}
*Horário:* {{hora}}

*1* — Confirmar
*2* — Escolher outro horário
*3* — Cancelar
```

### Passo 5 — Sucesso

```
✅ *Consulta agendada com sucesso!*

📋 {{especialidade}}
👤 {{nome_do_paciente}}
📅 {{data_extenso}}
⏰ {{hora}}
🆔 Código: {{appointment_id}}

Você receberá lembretes *24h* e *2h* antes.

_Para cancelar, digite *3*._
_Para remarcar, digite *4*._
```

---

## 3. Ver agendamentos (opção 2)

### Se tem consultas

```
📅 *Suas próximas consultas:*

*1* — sex, 27 jun às 10:40
    Cardiologia (ID: abc-123)

*2* — qua, 02 jul às 15:00
    Dermatologia (ID: def-456)

_Para cancelar, responda:_
*canc 1* (ou *canc 2*)

_Para remarcar, responda:_
*remarca 1 novo-horário* (ex: *remarca 1 11:00*)
```

### Se não tem

```
📭 Você não tem consultas agendadas no momento.

Quer *agendar* uma? É só digitar *1*. 😊
```

---

## 4. Cancelar consulta (opção 3)

### Confirmação antes de cancelar

```
Tem certeza que deseja cancelar essa consulta? 🤔

📋 {{especialidade}}
📅 {{data}}
⏰ {{hora}}

*1* — Sim, cancelar
*2* — Não, manter
```

### Sucesso

```
✅ *Consulta cancelada*

{{especialidade}}
{{data}} às {{hora}}

O horário foi liberado. Quando quiser, é só digitar *1* para agendar de novo. 😊
```

---

## 5. Remarcar consulta (opção 4)

### Pede nova data

```
Beleza! Vamos remarcar 📅

Sua consulta atual:
📋 {{especialidade}}
📅 {{data_antiga}}
⏰ {{hora_antiga}}

Qual a nova data? Responda no formato *DD/MM*
(ex: 28/06)
```

### Pede novo horário

```
E o novo horário? ⏰

Horários disponíveis em {{nova_data}}:

⏰ *09:00*
⏰ *11:20*
⏰ *15:30*

Qual prefere?
```

### Sucesso

```
🔄 *Consulta remarcada!*

{{especialidade}}
📅 {{nova_data_extenso}}
⏰ {{novo_horario}}

Os lembretes serão atualizados automaticamente. ✅
```

### Se horário ocupado

```
😕 Esse horário não está livre.

Escolha outro da lista acima, por favor.
```

---

## 6. Informações (opção 5)

```
📍 *Clínica Vida*

*Endereço:* Rua das Flores, 123 — Centro
*Telefone:* (11) 3333-4444
*Horário de atendimento:*
  Seg-Sex · 7h às 19h
  Sábado · 7h às 12h

*Convênios:* Unimed, Amil, SulAmérica, Bradesco Saúde
*Particular:* a partir de R$ 250

Quer *agendar* agora? É só digitar *1*. 🗓️
```

### Sub-perguntas comuns

**Convênio X é aceito?**
```
Trabalhamos com: Unimed, Amil, SulAmérica e Bradesco Saúde.

Se o seu for outro, me chama no *6* que a recepção te ajuda! 😊
```

**Como chegar?**
```
📍 Rua das Flores, 123 — Centro

🚇 Metrô: Estação Sé (5 min a pé)
🚌 Ônibus: linhas 102, 456, 789
🚗 Estacionamento: gratuito pra pacientes

Quer ver no mapa? https://maps.google.com/?q=Rua+das+Flores+123
```

**Vocês fazem exame de sangue?**
```
Sim! Coleta de sangue é feita *de 2ª a 6ª, das 7h às 10h*, em jejum.

Posso te *agendar* pra coleta? É só digitar *1*. 🩸
```

---

## 7. Falar com humano (opção 6)

```
Vou te transferir para um atendente humano 👩‍💼

Enquanto isso, descreve brevemente o assunto. Em horário comercial o retorno é em até *5 minutos*.

_Fora do horário, retornamos no próximo expediente._
```

> Aciona notificação interna pra equipe via WhatsApp Business separado.

---

## 8. Lembretes automáticos

### 24 horas antes

```
👋 Oi, {{primeiro_nome}}!

Lembrete: sua consulta é *amanhã*! 🗓️

📋 *{{especialidade}}*
👨‍⚕️ {{nome_do_medico}}
📅 {{data_extenso}}
⏰ {{hora}}
📍 Clínica Vida — Rua das Flores, 123

✅ Confirma presença?
*1* — Confirmo
*2* — Preciso remarcar
*3* — Cancelar
```

### 2 horas antes

```
⏰ *Daqui a 2 horas* você tem consulta!

📋 {{especialidade}}
⏰ {{hora}}
📍 Clínica Vida

Não esqueça de trazer:
• Documento com foto
• Carteirinha do convênio
• Exames anteriores (se tiver)

Até já! 😊
```

### Pós-consulta (6h depois)

```
Olá, {{primeiro_nome}}! 😊

Esperamos que sua consulta de *{{especialidade}}* tenha sido ótima!

Poderia nos dar uma avaliação rápida? Leva menos de 30 segundos!

⭐ *1* — Péssimo
⭐⭐ *2* — Ruim
⭐⭐⭐ *3* — Regular
⭐⭐⭐⭐ *4* — Bom
⭐⭐⭐⭐⭐ *5* — Excelente

Responda com o número de 1 a 5.
```

---

## 9. Mensagens de erro / fallback

### Não entendeu

```
Desculpa, não entendi 🤔

Pode tentar de novo? Você pode:

• Digitar *menu* pra ver as opções
• Escolher um número de *1* a *6*
• Falar com humano digitando *6*
```

### Horário ocupado

```
😕 Esse horário já está ocupado.

Quer que eu sugira outro horário disponível?
Responda *sim* ou envie outro horário (ex: 14:30).
```

### Sistema fora do ar (manutenção)

```
⚠️ Estamos em manutenção rápida.

Tenta de novo em alguns minutos ou liga pra nós:
📞 (11) 3333-4444

Pedimos desculpas pelo incômodo! 🙏
```

### Fora do horário

```
🌙 Estamos fora do horário de atendimento.

⏰ Nosso expediente:
  Seg-Sex · 7h às 19h
  Sábado · 7h às 12h

Deixe sua mensagem que respondemos assim que possível!

Para *emergência*, ligue *192* (SAMU) ou procure a UPA mais próxima.
```

---

## 10. Acessibilidade

- Use *negrito* com moderação (WhatsApp aceita `*texto*`)
- Use _itálico_ pra dicas (`_texto_`)
- Evite CAPS LOCK — texto maiúsculo parece que tá gritando
- Não dependa só de cor/emoji pra dar info (acessibilidade pra daltônicos)
- Mensagens curtas: WhatsApp quebra linha em telas pequenas, mantenha < 4 parágrafos

---

## 11. LGPD — mensagem inicial (importante!)

Adicione essa mensagem **uma vez** na primeira interação (state `INITIAL`):

```
Antes de continuar: ao usar esse atendimento, você concorda com nossa Política de Privacidade (link: clinicavida.com.br/privacidade).

Seus dados são protegidos conforme a LGPD. 💚
```

Salve `consent_lgpd = true` no DB.

---

## 12. Blacklist / Bloqueio

Se o paciente pedir descadastro:

```
Entendido. Você não receberá mais mensagens nossas.

Se precisar de algo no futuro, é só mandar um "oi" novamente.

Cuide-se! 💚
```

Adicione o número à tabela `blacklist` e o n8n ignora antes de processar.

---

## Variáveis dinâmicas disponíveis

Todos os textos podem usar:

| Variável | Fonte |
|---|---|
| `{{nome}}` | pushName do WhatsApp ou `patients.name` |
| `{{primeiro_nome}}` | primeiro nome só |
| `{{especialidade}}` | mapeamento de código → nome |
| `{{data}}` / `{{data_extenso}}` | formato curto / longo |
| `{{hora}}` | HH:MM |
| `{{nome_do_medico}}` | tabela doctors |
| `{{appointment_id}}` | UUID da consulta |

---

## 🎨 Customizações por clínica

Adapte os textos conforme o tom da sua clínica:

- **Clínica popular** → tom mais coloquial, mais emojis
- **Clínica premium** → tom sóbrio, sem emojis excessivos
- **Clínica pediátrica** → tom lúdico, use "mamãe/papai"
- **Clínica geriátrica** → letras maiúsculas em destaque, instruções passo a passo

Crie uma tabela `clinic_settings` no DB pra guardar por clínica:

```sql
CREATE TABLE clinic_settings (
  clinic_id UUID PRIMARY KEY,
  clinic_name VARCHAR(120),
  tone VARCHAR(20) DEFAULT 'casual',  -- casual | formal | playful
  welcome_message TEXT,
  custom_faq JSONB
);
```
