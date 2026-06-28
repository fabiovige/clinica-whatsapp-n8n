#!/usr/bin/env bash
# ============================================================
# Registra o webhook na Meta (WhatsApp Business Cloud API)
# Uso:
#   ./scripts/setup-meta-webhook.sh https://seu-dominio.com.br seu-token-aqui phone-id token-acesso
# ============================================================

set -e

if [[ $# -lt 4 ]]; then
  echo "Uso: $0 <WEBHOOK_URL> <VERIFY_TOKEN> <PHONE_NUMBER_ID> <ACCESS_TOKEN>"
  echo "Ex:  $0 https://atendimento.clinica.com.br meu-token-seguro 1234567890 EAAxxxxxxx"
  exit 1
fi

WEBHOOK_URL="$1"
VERIFY_TOKEN="$2"
PHONE_ID="$3"
ACCESS_TOKEN="$4"

API_VERSION="v21.0"
GRAPH_URL="https://graph.facebook.com/${API_VERSION}/${PHONE_ID}/subscribed_apps"

echo "Registrando webhook na Meta..."
echo "URL:      $WEBHOOK_URL/webhook/clinica-meta-webhook"
echo "Phone ID: $PHONE_ID"
echo ""

curl -s -X POST "$GRAPH_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"subscribed_fields\": [
      \"messages\",
      \"message_echoes\",
      \"message_template_status_update\",
      \"smb_message_echoes\"
    ]
  }" | jq .

echo ""
echo "Agora você precisa:"
echo "1) Ir em developers.facebook.com > seu app > WhatsApp > Configuration"
echo "2) Em 'Webhook', clicar 'Edit' e:"
echo "   Callback URL: $WEBHOOK_URL/webhook/clinica-meta-webhook"
echo "   Verify Token: $VERIFY_TOKEN"
echo "3) Confirmar verificação"
