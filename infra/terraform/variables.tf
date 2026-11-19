variable "project" {
  description = "Prefijo de todos los recursos."
  type        = string
  default     = "cidata-ojs"
}

variable "environment" {
  description = "Entorno (prod, staging)."
  type        = string
  default     = "prod"
}

variable "region" {
  description = "Región AWS. us-east-2 (Ohio) es la más económica para Venezuela."
  type        = string
  default     = "us-east-2"
}

variable "availability_zone" {
  description = "Zona de disponibilidad de Lightsail."
  type        = string
  default     = "us-east-2a"
}

variable "blueprint_id" {
  description = "Imagen base. Ubuntu 24.04 LTS."
  type        = string
  default     = "ubuntu_24_04"
}

variable "bundle_id" {
  description = "Plan de Lightsail. small_3_0 = 2 GB RAM, 2 vCPU, 60 GB SSD, 3 TB."
  type        = string
  default     = "small_3_0"
}

variable "domain" {
  description = "Dominio público de la revista."
  type        = string
  default     = "revedacyt.cidata.gob.ve"
}

variable "ssh_public_key_path" {
  description = "Clave pública SSH que se importará en Lightsail."
  type        = string
  default     = "~/.ssh/cidata-ojs.pub"
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado para SSH. 0.0.0.0/0 es cómodo al inicio; restringir después."
  type        = string
  default     = "0.0.0.0/0"
}

variable "budget_limit_usd" {
  description = "Presupuesto mensual de alerta."
  type        = number
  default     = 20
}

variable "alert_email" {
  description = "Correo que recibirá las alertas de presupuesto."
  type        = string
  default     = "admin@cidata.gob.ve"
}
