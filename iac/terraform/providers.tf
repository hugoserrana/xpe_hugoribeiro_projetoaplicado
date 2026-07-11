provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "Moro"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
