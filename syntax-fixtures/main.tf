terraform {
  required_version = ">= 1.6.0"
}

variable "app_name" {
  type    = string
  default = "reviu"
}

locals {
  replicas = 2
  tags = {
    env   = "dev"
    owner = var.app_name
  }
}

resource "aws_s3_bucket" "logs" {
  bucket        = "${var.app_name}-logs"
  force_destroy = true

  lifecycle {
    prevent_destroy = false
  }
}

output "summary" {
  value = join("-", [var.app_name, tostring(local.replicas)])
}

output "config" {
  value = <<-EOT
  app=${var.app_name}
  replicas=${local.replicas}
  EOT
}
