terraform {
  backend "s3" {
    bucket = "kafka-k8s-tfstate"
    key    = "default.tfstate"
    region = "eu-central-1"
  }
}