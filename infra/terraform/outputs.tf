output "instance_name" {
  value = aws_lightsail_instance.this.name
}

output "static_ip" {
  description = "IP que debe apuntar el registro A de journal.cidata.gob.ve."
  value       = aws_lightsail_static_ip.this.ip_address
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/cidata-ojs ubuntu@${aws_lightsail_static_ip.this.ip_address}"
}

output "dns_record" {
  description = "Datos exactos para el proveedor DNS."
  value       = "A | ${split(".", var.domain)[0]} | ${aws_lightsail_static_ip.this.ip_address} | TTL 300"
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "backup_access_key_id" {
  value     = aws_iam_access_key.backup.id
  sensitive = true
}

output "backup_secret_access_key" {
  value     = aws_iam_access_key.backup.secret
  sensitive = true
}
