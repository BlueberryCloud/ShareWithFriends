@"
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}
provider "kubernetes" {
  config_context = "docker-desktop"
}
"@ | Out-File versions.tf -Encoding utf8
