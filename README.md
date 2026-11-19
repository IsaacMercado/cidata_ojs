# REVEDACYT

Revista Venezolana de Divulgación Astronómica, Científica y Tecnológica.

Instalación de OJS 3.5 sobre Docker Compose, con Caddy para HTTPS automático,
MariaDB como base de datos y respaldos diarios a S3.

## Arquitectura

```text
Internet
   │ 80/443
   ▼
Caddy (TLS, redirección HTTP→HTTPS)
   │ 80 (red interna)
   ▼
OJS 3.5 (Apache/PHP)
   │ 3306 (red interna)
   ▼
MariaDB 11.8
```

Solo Caddy publica puertos. OJS y MariaDB quedan en la red interna de Docker.

## Estructura del repositorio

```text
.
├── compose.yaml          # Caddy + OJS + MariaDB
├── Caddyfile             # TLS y proxy
├── .env.example          # plantilla de configuración
├── install.sh            # instalación idempotente
├── config/
│   ├── apache.pkp.conf
│   ├── php.custom.ini
│   └── pkp.config.inc.php.template
├── theme/
│   └── revedacyt/        # tema propio
├── scripts/
│   ├── backup.sh
│   └── restore.sh
└── infra/terraform/      # opcional: recrear la infraestructura
```

Los datos **no** están en el repositorio. Viven en `./volumes/` y se respaldan
aparte.

## Requisitos

- Ubuntu 24.04 (o similar) con Docker y el plugin `docker compose`.
- `git`, `python3` y `openssl`.
- Un dominio con registro A apuntando al servidor.
- Puertos 22, 80 y 443 abiertos.
- 2 GB de RAM como mínimo.

Instalación rápida de Docker:

```bash
sudo apt update
sudo apt install -y git python3 openssl
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
```

## Primera instalación

### 1. DNS

Crea un registro A:

| Tipo | Nombre | Valor |
|---|---|---|
| A | `revedacyt` | IP estática del servidor |

No crees `AAAA`. No toques `MX`, `SPF` ni `DMARC`.

### 2. Clonar el repositorio

```bash
sudo git clone https://github.com/IsaacMercado/cidata_ojs.git /opt/ojs
cd /opt/ojs
```

### 3. Configurar

```bash
sudo cp .env.example .env
sudo nano .env
```

Como mínimo revisa:

| Variable | Valor |
|---|---|
| `SERVERNAME` | `revedacyt.cidata.gob.ve` |
| `ACME_EMAIL` | correo para Let's Encrypt |
| `OJS_ADMIN_EMAIL` | correo del administrador |
| `DB_NAME`, `DB_USER` | nombre y usuario de la base |
| `BACKUP_BUCKET` | bucket S3, o vacío para solo copias locales |

Las contraseñas de base de datos, el usuario admin y los secretos de OJS se
generan automáticamente si están vacíos.

### 4. Instalar

```bash
sudo bash install.sh
```

El script:

1. Genera los secretos que falten.
2. Prepara `volumes/` y los permisos.
3. Descarga las imágenes de MariaDB, OJS y Caddy.
4. Arranca MariaDB y espera su healthcheck.
5. Instala OJS por consola solo si `installed = Off`.
6. Ajusta `base_url`, HTTPS, URLs limpias, sal de sesión y SMTP.
7. Arranca Caddy y pide el certificado a Let's Encrypt.
8. Instala el cron de tareas de OJS y el respaldo diario.

Al terminar muestra la URL y la contraseña inicial del administrador. También
queda en `.env`:

```bash
sudo grep OJS_ADMIN_PASSWORD /opt/ojs/.env
```

### 5. Primer inicio de sesión

```text
https://revedacyt.cidata.gob.ve/index/es/login
```

Cambia la contraseña de `admin` en el primer acceso. El formulario de OJS acepta
como máximo 32 caracteres.

## Correo saliente

OJS puede enviar correo por SMTP o no enviar nada (`log`).

Para configurar SMTP:

```bash
sudo install -d -m 700 /opt/ojs/secrets
sudo sh -c 'printf %s "TU_CONTRASEÑA" > /opt/ojs/secrets/smtp_password'
sudo chmod 600 /opt/ojs/secrets/smtp_password
```

Edita `.env`:

```dotenv
SMTP_HOST=mail.cidata.gob.ve
SMTP_PORT=465
SMTP_AUTH=ssl
SMTP_USER=soporte@cidata.gob.ve
SMTP_FROM=soporte@cidata.gob.ve
SMTP_PASSWORD_FILE=secrets/smtp_password
```

Y vuelve a ejecutar:

```bash
sudo bash install.sh
```

También puedes configurar el correo desde **Administración → Configuración →
Correo** y enviar un mensaje de prueba.

## Actualizar

```bash
cd /opt/ojs
sudo git pull
sudo bash install.sh
```

Es idempotente: conserva la base de datos, los archivos y las opciones de la
revista. Solo reinicia los contenedores.

Para actualizar OJS:

1. Cambia `OJS_VERSION` en `.env`.
2. Ejecuta `sudo bash install.sh`.
3. Ejecuta la migración:

```bash
sudo docker exec ojs-app /usr/local/bin/pkp-upgrade
```

Prueba login, envío, subida de PDF y OAI después de migrar.

## Respaldos

El cron instala:

- Tareas de OJS cada 15 minutos.
- Respaldo diario a las 03:15.

Respaldo manual:

```bash
sudo bash scripts/backup.sh
```

Destino local: `/opt/ojs/backups/`.
Destino S3: `s3://<BACKUP_BUCKET>/daily/`.

El perfil `backups` de AWS CLI debe existir en root:

```bash
sudo aws configure --profile backups
```

Restaurar:

```bash
sudo bash scripts/restore.sh db    backups/db-2026-11-06_0300.sql.gz
sudo bash scripts/restore.sh files backups/files-2026-11-06_0300.tar.gz
sudo docker compose restart app
```

El respaldo incluye base de datos, archivos privados y archivos públicos. **No**
incluye `.env` ni `secrets/`: guarda una copia segura de esos archivos en un
gestor de contraseñas.

## Logs y diagnóstico

```bash
sudo docker compose ps
sudo docker compose logs -f app
sudo docker compose logs -f caddy
sudo docker compose logs -f db
```

| Síntoma | Causa probable |
|---|---|
| Caddy: `NXDOMAIN` | El registro A no existe o no propagó. |
| 502 Bad Gateway | `ojs-app` caído. Revisa `docker compose ps`. |
| Subida de PDF falla | Límite de PHP; revisa `config/php.custom.ini`. |
| No salen correos | SMTP vacío o credenciales incorrectas. |
| Disco lleno | Revisa `df -h` y limpia respaldos locales. |

## Seguridad

- SSH solo con clave.
- Firewall del proveedor: solo 22, 80 y 443.
- MariaDB no publica puertos.
- HTTPS con Let's Encrypt.
- Cambia la contraseña inicial de `admin`.
- Activa MFA en la cuenta de AWS.
- Restringe el acceso SSH a tu red cuando tengas IP fija.
- Guarda `.env` y `secrets/` fuera del repositorio.

## Infraestructura opcional

`infra/terraform/` contiene la definición de la instancia Lightsail, IP estática,
firewall, S3, IAM y presupuesto. **No se necesita para desplegar la aplicación**;
solo para recrear la infraestructura desde cero con OpenTofu. El flujo normal es
clonar el repositorio y ejecutar `install.sh`.

## Qué no se versiona

- `.env`, `secrets/`, `config.ini`.
- `volumes/` (base de datos y archivos de la revista).
- `backups/`.
- `dev/` y `archive/` (entorno local y material histórico).
- Cachés de OpenTofu, `tfplan`, `.terraform/`.

El repositorio contiene solo lo necesario para instalar, operar y recuperar la
aplicación.
