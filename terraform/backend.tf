terraform {
  backend "s3" {
    bucket  = "tfstate-fiap-alex-academy-gtw-1"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = false
  }
}
