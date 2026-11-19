#!/usr/bin/env bash
# Restauración manual.
#   sudo bash scripts/restore.sh db    backups/db-2026-11-06_0300.sql.gz
#   sudo bash scripts/restore.sh files backups/files-2026-11-06_0300.tar.gz
set -euo pipefail

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

set -a
# shellcheck disable=SC1091
. ./.env
set +a

MODE="${1:?Uso: restore.sh db|files RUTA}"
FILE="${2:?Falta la ruta del respaldo}"

case "$MODE" in
  db)
    echo "Restaurando base de datos desde $FILE"
    gunzip -c "$FILE" | docker exec -i ojs-db mariadb -uroot -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
    ;;
  files)
    echo "Restaurando archivos desde $FILE"
    tar xzf "$FILE" -C "$APP_DIR/volumes"
    chown -R 33:33 "$APP_DIR/volumes/private" "$APP_DIR/volumes/public"
    ;;
  *)
    echo "Modo inválido: $MODE (usar db o files)" >&2
    exit 1
    ;;
esac

echo "Restauración terminada. Reinicia con:"
echo "  cd $APP_DIR && docker compose restart app"
