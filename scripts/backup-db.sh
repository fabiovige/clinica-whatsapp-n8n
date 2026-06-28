#!/usr/bin/env bash
# ============================================================
# Backup automático do PostgreSQL
# Adicione ao crontab:
#   crontab -e
#   0 3 * * * /home/SEU_USER/clinica-whatsapp-n8n/scripts/backup-db.sh
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="clinica_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

cd "$PROJECT_DIR"

echo "[$(date)] Iniciando backup..."

# pega senha do .env
POSTGRES_PASSWORD=$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
export PGPASSWORD="$POSTGRES_PASSWORD"

# backup
docker exec clinica-postgres pg_dump -U postgres -d clinica | gzip > "$BACKUP_DIR/$FILENAME"

# mantém só os últimos 30
find "$BACKUP_DIR" -name "clinica_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Backup salvo: $BACKUP_DIR/$FILENAME"

unset PGPASSWORD
