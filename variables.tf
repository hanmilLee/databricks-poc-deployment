variable "env_name" {
  type    = string
  default = "databricks workspace"
}

variable "user_name" {
  type        = string
  description = "firstname.lastname"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "prefix" {
  type        = string
  description = "Prefix for AWS and Databricks resource names"
  default     = "mycompany001-poc"
}

variable "deployment_name" {
  type        = string
  description = "Optional Databricks workspace deployment name for URL customization"
  default     = null
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks account id from accounts console"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cidr_block" {
  type    = string
  default = "10.4.0.0/16"
}

locals {
  prefix = var.prefix
  tags = merge(
    {
      Owner       = var.user_name
      Environment = var.env_name
    },
    var.tags
  )
}
