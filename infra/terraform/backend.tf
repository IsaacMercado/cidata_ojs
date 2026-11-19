terraform {
  # Estado remoto: se crea una sola vez con infra/terraform/bootstrap.sh.
  # El bloqueo usa el fichero nativo de S3 (Terraform >= 1.10), sin DynamoDB.
  backend "s3" {
    bucket       = "cidata-ojs-tfstate-947567203188"
    key          = "lightsail/prod/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
