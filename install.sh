#!/usr/bin/env bash
# ============================================================
# REVEDACYT — instalación idempotente de OJS + Caddy + MariaDB
#
# Uso:
#   cp .env.example .env
#   nano .env
#   sudo bash install.sh
#
# Se puede ejecutar varias veces. Solo instala OJS si todavía
# no está instalado y conserva la base de datos y los archivos.
# ============================================================
set -euo pipefail

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

log() { printf '\n== %s ==\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Ejecuta este script con sudo."
command -v docker >/dev/null 2>&1 || die "Docker no está instalado."
docker compose version >/dev/null 2>&1 || die "Falta el plugin 'docker compose'."
command -v openssl >/dev/null 2>&1 || die "Falta openssl."
command -v python3 >/dev/null 2>&1 || die "Falta python3."

# ------------------------------------------------------------
# 1. Configuración y secretos
# ------------------------------------------------------------
if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "Se creó .env a partir de .env.example. Revisa SERVERNAME y DB_*."
fi

ensure_secret() {
  local key="$1" bytes="${2:-24}" current value
  current="$(grep -E "^${key}=" .env | head -n1 | cut -d= -f2- || true)"
  if [ -z "$current" ]; then
    value="$(openssl rand -hex "$bytes")"
    if grep -qE "^${key}=" .env; then
      sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
      printf '%s=%s\n' "$key" "$value" >> .env
    fi
  fi
}

ensure_secret DB_PASSWORD
ensure_secret DB_ROOT_PASSWORD
# El login de OJS acepta como máximo 32 caracteres: 12 bytes = 24 hex.
ensure_secret OJS_ADMIN_PASSWORD 12
ensure_secret OJS_SALT
ensure_secret OJS_API_KEY_SECRET
chmod 600 .env

set -a
# shellcheck disable=SC1091
. ./.env
set +a

: "${SERVERNAME:?Falta SERVERNAME en .env}"
: "${DB_NAME:?Falta DB_NAME en .env}"
: "${DB_USER:?Falta DB_USER en .env}"
: "${DB_PASSWORD:?Falta DB_PASSWORD en .env}"
: "${DB_ROOT_PASSWORD:?Falta DB_ROOT_PASSWORD en .env}"

case "$SERVERNAME" in
  *://*|*/) die "SERVERNAME debe ser un dominio sin https:// ni barra final." ;;
esac

export OJS_ADMIN_USER="${OJS_ADMIN_USER:-admin}"
export OJS_ADMIN_EMAIL="${OJS_ADMIN_EMAIL:-soporte@cidata.gob.ve}"

log "Preparando correo"
SMTP_PASSWORD_FILE="${SMTP_PASSWORD_FILE:-}"
if [ -n "${SMTP_PASSWORD:-}" ]; then
  install -d -m 700 "$APP_DIR/secrets"
  printf '%s' "$SMTP_PASSWORD" > "$APP_DIR/secrets/smtp_password"
  chmod 600 "$APP_DIR/secrets/smtp_password"
  SMTP_PASSWORD_FILE="$APP_DIR/secrets/smtp_password"
fi
case "$SMTP_PASSWORD_FILE" in
  /*) ;;
  "") ;;
  *) SMTP_PASSWORD_FILE="$APP_DIR/$SMTP_PASSWORD_FILE" ;;
esac
if [ -n "${SMTP_HOST:-}" ]; then
  [ -f "$SMTP_PASSWORD_FILE" ] || die "SMTP_HOST está definido pero no existe $SMTP_PASSWORD_FILE"
  export OJS_MAIL_METHOD=smtp
else
  export OJS_MAIL_METHOD="${OJS_MAIL_METHOD:-log}"
fi
export SMTP_PASSWORD_FILE

# ------------------------------------------------------------
# 2. Ajustes de red para enlaces con latencia o pérdida
# ------------------------------------------------------------
log "Aplicando ajustes de red"
if [ -d /etc/sysctl.d ]; then
  cat > /etc/sysctl.d/99-cidata-net.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
EOF
  modprobe tcp_bbr 2>/dev/null || true
  sysctl --system >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# 3. Volúmenes, configuración y permisos
# ------------------------------------------------------------
log "Preparando volúmenes y configuración"
install -d -m 700 "$APP_DIR/secrets"
mkdir -p "$APP_DIR/volumes/db" \
         "$APP_DIR/volumes/private" \
         "$APP_DIR/volumes/public" \
         "$APP_DIR/volumes/config" \
         "$APP_DIR/volumes/caddy/data" \
         "$APP_DIR/volumes/caddy/config"

if [ ! -s "$APP_DIR/volumes/config/pkp.config.inc.php" ]; then
  cp "$APP_DIR/config/pkp.config.inc.php.template" \
     "$APP_DIR/volumes/config/pkp.config.inc.php"
fi
cp "$APP_DIR/config/php.custom.ini" "$APP_DIR/volumes/config/php.custom.ini"
cp "$APP_DIR/config/apache.pkp.conf" "$APP_DIR/volumes/config/apache.pkp.conf"
sed -i "s/www.example.com/${SERVERNAME}/g" "$APP_DIR/volumes/config/apache.pkp.conf"

chown 33:33 "$APP_DIR/volumes/config/pkp.config.inc.php" \
             "$APP_DIR/volumes/config/php.custom.ini" \
             "$APP_DIR/volumes/config/apache.pkp.conf"
chmod 664 "$APP_DIR/volumes/config/pkp.config.inc.php"
chown -R 33:33 "$APP_DIR/volumes/private" "$APP_DIR/volumes/public"
chown -R 999:999 "$APP_DIR/volumes/db"

# ------------------------------------------------------------
# 4. Imágenes y base de datos
# ------------------------------------------------------------
log "Descargando imágenes"
docker compose pull db caddy app

log "Arrancando MariaDB"
docker compose up -d db

ready=false
for _ in $(seq 1 60); do
  if docker exec ojs-db healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
if [ "$ready" != true ]; then
  docker compose logs db | tail -50
  die "MariaDB no arrancó a tiempo."
fi

# ------------------------------------------------------------
# 5. OJS
# ------------------------------------------------------------
log "Arrancando OJS"
docker compose up -d app
sleep 10

if grep -q '^installed = Off' "$APP_DIR/volumes/config/pkp.config.inc.php"; then
  if docker exec ojs-db mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
       -e "SELECT 1 FROM journals LIMIT 1" >/dev/null 2>&1; then
    log "La base ya contiene OJS; se marca installed = On y se omite el instalador"
    sed -i 's/^installed = Off/installed = On/' \
      "$APP_DIR/volumes/config/pkp.config.inc.php"
  else
    log "Instalando OJS (solo la primera vez)"
    docker exec -i ojs-app php tools/install.php <<EOF
es
en
/var/www/files
${OJS_ADMIN_USER}
${OJS_ADMIN_PASSWORD}
${OJS_ADMIN_PASSWORD}
${OJS_ADMIN_EMAIL}
mariadb
db
${DB_USER}
${DB_PASSWORD}
${DB_NAME}
${SERVERNAME}
n
y
EOF
  fi
else
  log "OJS ya está instalado; se omite el instalador"
fi

log "Ajustando config.inc.php"
SERVERNAME="$SERVERNAME" \
OJS_SALT="$OJS_SALT" \
OJS_API_KEY_SECRET="$OJS_API_KEY_SECRET" \
SMTP_HOST="${SMTP_HOST:-}" \
SMTP_PORT="${SMTP_PORT:-465}" \
SMTP_AUTH="${SMTP_AUTH:-ssl}" \
SMTP_USER="${SMTP_USER:-}" \
SMTP_PASSWORD="${SMTP_PASSWORD:-}" \
SMTP_PASSWORD_FILE="$SMTP_PASSWORD_FILE" \
SMTP_FROM="${SMTP_FROM:-}" \
OJS_MAIL_METHOD="$OJS_MAIL_METHOD" \
python3 - "$APP_DIR/volumes/config/pkp.config.inc.php" <<'PY'
from __future__ import annotations

import os
import re
import sys

path = sys.argv[1]
server = os.environ["SERVERNAME"]


def php_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


smtp_password = os.environ.get("SMTP_PASSWORD", "")
if os.environ.get("SMTP_PASSWORD_FILE"):
    try:
        with open(os.environ["SMTP_PASSWORD_FILE"], encoding="utf-8") as fh:
            smtp_password = fh.read()
        if smtp_password.endswith("\n"):
            smtp_password = smtp_password[:-1]
    except OSError:
        pass

settings: dict[str, dict[str, str]] = {
    "general": {
        "base_url": f'"https://{server}"',
        "allowed_hosts": f"'[\"{server}\"]'",
        "installed": "On",
        "restful_urls": "On",
    },
    "files": {
        "files_dir": '"/var/www/files"',
        "public_files_dir": '"public"',
    },
    "security": {
        "force_ssl": "On",
        "force_login_ssl": "On",
        "session_check_ip": "Off",
        "salt": f'"{os.environ["OJS_SALT"]}"',
        "api_key_secret": f'"{os.environ["OJS_API_KEY_SECRET"]}"',
    },
    "email": {
        "default": os.environ.get("OJS_MAIL_METHOD", "log"),
    },
}

if os.environ.get("SMTP_HOST"):
    settings["email"].update(
        {
            "smtp": "On",
            "smtp_server": php_string(os.environ["SMTP_HOST"]),
            "smtp_port": os.environ.get("SMTP_PORT", "465"),
            "smtp_auth": os.environ.get("SMTP_AUTH", "ssl"),
            "smtp_username": php_string(os.environ.get("SMTP_USER", "")),
            "smtp_password": php_string(smtp_password),
        }
    )
    if os.environ.get("SMTP_FROM"):
        settings["email"]["default_envelope_sender"] = php_string(os.environ["SMTP_FROM"])

lines = open(path, encoding="utf-8").read().splitlines()
section: str | None = None
seen = {name: set() for name in settings}
output: list[str] = []

for line in lines:
    match = re.match(r"^\s*\[([^\]]+)\]\s*$", line)
    if match:
        if section in settings:
            for key in settings[section]:
                if key not in seen[section]:
                    output.append(f"{key} = {settings[section][key]}")
        section = match.group(1)
        output.append(line)
        continue

    if section in settings:
        key_match = re.match(r"^(\s*)([A-Za-z0-9_]+)(\s*=\s*)(.*)$", line)
        if key_match and key_match.group(2) in settings[section]:
            key = key_match.group(2)
            output.append(f"{key_match.group(1)}{key}{key_match.group(3)}{settings[section][key]}")
            seen[section].add(key)
            continue

    output.append(line)

if section in settings:
    for key in settings[section]:
        if key not in seen[section]:
            output.append(f"{key} = {settings[section][key]}")

open(path, "w", encoding="utf-8").write("\n".join(output) + "\n")
print(f"config.inc.php actualizado para {server}")
PY

chown 33:33 "$APP_DIR/volumes/config/pkp.config.inc.php"
chmod 664 "$APP_DIR/volumes/config/pkp.config.inc.php"

log "Reiniciando OJS y arrancando Caddy"
docker compose restart app
# OJS concatena CSS en cache; se limpia para que los cambios del tema se vean.
docker exec ojs-app sh -c 'rm -f /var/www/html/cache/*.css' 2>/dev/null || true
docker compose up -d caddy
# Caddy no recarga solo el Caddyfile montado; se reinicia para aplicar cambios.
docker compose restart caddy

# ------------------------------------------------------------
# 6. Tareas programadas y respaldo diario
# ------------------------------------------------------------
log "Instalando cron"
cat > /etc/cron.d/cidata-ojs <<CRON
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/15 * * * * root cd "$APP_DIR" && docker exec ojs-app /usr/local/bin/pkp-run-scheduled >/dev/null 2>&1
15 3 * * * root "$APP_DIR/scripts/backup.sh" >> /var/log/cidata-ojs-backup.log 2>&1
CRON
chmod 644 /etc/cron.d/cidata-ojs
chmod +x "$APP_DIR/scripts/backup.sh" "$APP_DIR/scripts/restore.sh"

# ------------------------------------------------------------
# 7. Resumen
# ------------------------------------------------------------
log "Listo"
docker compose ps
echo
echo "URL:         https://${SERVERNAME}"
echo "Usuario:     ${OJS_ADMIN_USER}"
echo "Contraseña:  ${OJS_ADMIN_PASSWORD}"
echo "La contraseña también está en $APP_DIR/.env (root, 0600)."
echo
echo "Cambia la contraseña en el primer inicio de sesión."
