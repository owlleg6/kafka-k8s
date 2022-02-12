variable "cluster_name" {
  type    = string
  default = ""
}

variable "tfstate_bucket" {
  type    = string
  default = ""
}

variable "cidr" {
  type    = string
}

variable "aws_region" {
  type = string
}

variable "private_subnets" {
  type = list(string)
  description = "List of private subnets"
}

variable "public_subnets" {
  type = list(string)
  description = "List of public subnets"
}

