#!/usr/bin/env bash
# Respaldo diario: base de datos + archivos privados/públicos -> S3.
set -euo pipefail

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

set -a
# shellcheck disable=SC1091
. ./.env
set +a

DATE="$(date +%Y-%m-%d_%H%M)"
DIR="$APP_DIR/backups"
mkdir -p "$DIR"

echo "[$(date -Is)] Iniciando respaldo $DATE"

docker exec ojs-db mariadb-dump \
  -uroot -p"${DB_ROOT_PASSWORD}" \
  --single-transaction --quick --routines --triggers \
  "${DB_NAME}" | gzip > "$DIR/db-$DATE.sql.gz"

tar czf "$DIR/files-$DATE.tar.gz" -C "$APP_DIR/volumes" private public

if [ -n "${BACKUP_BUCKET:-}" ]; then
  AWS_PROFILE=backups aws s3 cp "$DIR/db-$DATE.sql.gz" "s3://${BACKUP_BUCKET}/daily/"
  AWS_PROFILE=backups aws s3 cp "$DIR/files-$DATE.tar.gz" "s3://${BACKUP_BUCKET}/daily/"

  if [ "$(date +%d)" = "01" ]; then
    AWS_PROFILE=backups aws s3 cp "$DIR/db-$DATE.sql.gz" "s3://${BACKUP_BUCKET}/monthly/"
    AWS_PROFILE=backups aws s3 cp "$DIR/files-$DATE.tar.gz" "s3://${BACKUP_BUCKET}/monthly/"
  fi
else
  echo "BACKUP_BUCKET vacío: solo se guardó copia local" >&2
fi

find "$DIR" -type f -mtime +7 -delete
echo "[$(date -Is)] Respaldo terminado"
