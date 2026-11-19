data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Servidor Lightsail
# ---------------------------------------------------------------------------

resource "aws_lightsail_key_pair" "this" {
  # Lightsail comparte el espacio de nombres entre instancias y claves:
  # no puede llamarse igual que la instancia.
  name       = "${var.project}-${var.environment}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_lightsail_static_ip" "this" {
  name = "${var.project}-${var.environment}-ip"
}

resource "aws_lightsail_instance" "this" {
  name              = "${var.project}-${var.environment}"
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint_id
  bundle_id         = var.bundle_id
  key_pair_name     = aws_lightsail_key_pair.this.name
  ip_address_type   = "ipv4"

  # Lightsail antepone su propio script de inicialización, así que un shebang
  # aquí quedaría como comentario. Por eso enviamos un comando directo de una
  # sola línea que decodifica y ejecuta el bootstrap completo.
  user_data = "echo ${base64encode(file("${path.module}/cloud-init.sh"))} | base64 -d | bash"

  add_on {
    type          = "AutoSnapshot"
    snapshot_time = "06:00" # 02:00 en America/Caracas
    status        = "Enabled"
  }

  tags = {
    Name   = "${var.project}-${var.environment}"
    Domain = var.domain
  }

  # Evita que un cambio en el bootstrap reconstruya la instancia por accidente.
  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "aws_lightsail_static_ip_attachment" "this" {
  static_ip_name = aws_lightsail_static_ip.this.name
  instance_name  = aws_lightsail_instance.this.name

  # Si la instancia se recrea con el mismo nombre, Lightsail suelta la IP.
  # Esto fuerza a reasociarla.
  lifecycle {
    replace_triggered_by = [aws_lightsail_instance.this.id]
  }
}

resource "aws_lightsail_instance_public_ports" "this" {
  instance_name = aws_lightsail_instance.this.name

  lifecycle {
    replace_triggered_by = [aws_lightsail_instance.this.id]
  }

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidrs     = [var.ssh_allowed_cidr]
  }

  port_info {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
    cidrs     = ["0.0.0.0/0"]
  }

  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
    cidrs     = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Copias de seguridad en S3
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  bucket = "${var.project}-${var.environment}-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "daily"
    status = "Enabled"
    filter {
      prefix = "daily/"
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "monthly"
    status = "Enabled"
    filter {
      prefix = "monthly/"
    }
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "backups_tls" {
  bucket = aws_s3_bucket.backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.backups.arn,
          "${aws_s3_bucket.backups.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_iam_user" "backup" {
  name = "${var.project}-${var.environment}-backup"
}

resource "aws_iam_user_policy" "backup" {
  name = "${var.project}-${var.environment}-backup"
  user = aws_iam_user.backup.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBackupPrefixes"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.backups.arn]
        Condition = {
          StringLike = {
            "s3:prefix" = ["daily/*", "monthly/*"]
          }
        }
      },
      {
        Sid      = "ReadWriteBackups"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = [
          "${aws_s3_bucket.backups.arn}/daily/*",
          "${aws_s3_bucket.backups.arn}/monthly/*",
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}

# ---------------------------------------------------------------------------
# Presupuesto y alerta
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-${var.environment}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
