#!/bin/bash
# Bootstrap mínimo del servidor. Lo ejecuta Lightsail en el primer arranque.
# No contiene secretos: las contraseñas se generan luego en /opt/ojs/.env.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Esperar a que apt esté libre (cloud-init puede competir con unattended-upgrades).
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done

apt-get update
apt-get -y upgrade
apt-get -y install \
  ca-certificates curl gnupg lsb-release ufw fail2ban \
  unattended-upgrades jq unzip htop git python3

# AWS CLI v2 (el paquete "awscli" no existe en Ubuntu 24.04).
case "$(uname -m)" in
  x86_64) AWS_ARCH=x86_64 ;;
  aarch64) AWS_ARCH=aarch64 ;;
  *) echo "Arquitectura no soportada: $(uname -m)"; exit 1 ;;
esac
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Docker desde el repositorio oficial.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# Swap de 2 GB (el plan tiene 2 GB de RAM).
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
sysctl -w vm.swappiness=10
echo 'vm.swappiness=10' > /etc/sysctl.d/99-cidata-swap.conf

# Zona horaria de la revista.
timedatectl set-timezone America/Caracas

# Estructura de la aplicación.
mkdir -p /opt/ojs/volumes/{db,private,public,config,caddy/data,caddy/config}
mkdir -p /opt/ojs/backups /opt/ojs/theme
chown -R 33:33 /opt/ojs/volumes/private /opt/ojs/volumes/public /opt/ojs/volumes/config
chown -R 999:999 /opt/ojs/volumes/db

# Firewall local (Lightsail ya filtra; esto es defensa en profundidad).
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Actualizaciones de seguridad automáticas.
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now fail2ban

# Rotación de logs de Docker para no llenar el disco.
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker

echo "cidata-ojs bootstrap OK $(date -Is)" > /var/log/cidata-bootstrap.log
