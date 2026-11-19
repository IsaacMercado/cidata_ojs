# Infraestructura AWS Lightsail con OpenTofu

Esta carpeta crea y mantiene la infraestructura de la revista. **No** despliega la
aplicación: eso lo hace `install.sh` en la raíz del repositorio.

## Qué crea

| Recurso | Detalle |
|---|---|
| Instancia Lightsail | `cidata-ojs-prod`, Ubuntu 24.04, 2 GB RAM, 2 vCPU, 60 GB SSD, `us-east-2a` |
| IP estática | `3.19.113.93` (se mantiene al reiniciar) |
| Firewall | 22, 80 y 443; MariaDB y la app no se exponen |
| Snapshots | Automáticos todos los días a las 06:00 UTC (02:00 Venezuela) |
| Bucket S3 | `cidata-ojs-prod-backups-947567203188`, privado, cifrado, versionado |
| Usuario IAM | Solo puede leer/escribir en `daily/` y `monthly/` del bucket |
| Presupuesto | 20 USD/mes con alertas al 80 % y al 100 % previsto |
| Clave SSH | Importada desde `~/.ssh/cidata-ojs.pub` |

## Requisitos

- AWS CLI configurado (`aws sts get-caller-identity`).
- **OpenTofu** (`tofu`), no Terraform: `registry.terraform.io` está bloqueado
  geográficamente desde Venezuela. OpenTofu usa `registry.opentofu.org` y es
  compatible con esta configuración.
- Clave SSH local:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/cidata-ojs -N "" -C cidata-ojs
```

## Primer uso

```bash
cd infra/terraform
bash bootstrap.sh          # crea el bucket de estado (una sola vez)
tofu init
tofu plan
tofu apply
tofu output
```

## Salidas útiles

```bash
tofu output -raw static_ip
tofu output -raw dns_record
tofu output -raw ssh_command
```

## Estado remoto

- Bucket: `s3://cidata-ojs-tfstate-947567203188`
- Key: `lightsail/prod/terraform.tfstate`
- Cifrado AES256, versionado y bloqueo nativo de S3 (`use_lockfile`).

El estado contiene la clave de acceso del usuario de backups. El bucket es
privado; no compartas el estado ni lo subas a Git.

## Cambiar el dominio o el acceso SSH

Edita `terraform.tfvars` (copia de `terraform.tfvars.example`):

```hcl
domain           = "revedacyt.cidata.gob.ve"
ssh_allowed_cidr = "203.0.113.10/32"
```

Y aplica:

```bash
tofu apply
```

Al principio se deja `0.0.0.0/0` para no quedar fuera si cambia la IP. Cuando el
acceso esté estable, restringe a tu red.

## Costos estimados (us-east-2)

| Concepto | USD/mes |
|---|---:|
| Lightsail 2 GB | 12,00 |
| Snapshots (~20–40 GB incrementales) | 1,00–2,00 |
| S3 (backups pequeños) | 0,10–0,50 |
| **Total** | **~13–15** |

## Recrear la instancia

Lightsail **suelta la IP estática** cuando se destruye la instancia. El recurso
`aws_lightsail_static_ip_attachment` tiene `replace_triggered_by` para volver a
asociarla automáticamente.

El `user_data` se ignora después de la creación (`ignore_changes`) para evitar
recreaciones accidentales. Si cambias `cloud-init.sh`, applícalo manualmente o
recrea la instancia con `tofu apply -replace=aws_lightsail_instance.this`.

## Destruir

```bash
tofu destroy
```

Elimina la instancia, la IP y el usuario IAM. El bucket S3 tiene
`force_destroy = false`: si hay respaldos, el destroy fallará para protegerlos.
No lo ejecutes en producción sin respaldo y confirmación.
