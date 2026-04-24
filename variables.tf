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
  description = "Workspace URL name. Use only when deployment_name_prefix_enabled is true."
  default     = null
}

variable "deployment_name_prefix_enabled" {
  type        = bool
  description = "Set true only when Databricks account deployment name prefix is enabled."
  default     = false
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

variable "metastore_id" {
  type        = string
  description = "할당할 Unity Catalog Metastore ID (Account Console에서 확인)"
  default     = ""
}

variable "enable_unity_catalog" {
  type        = bool
  description = "Unity Catalog 리소스(S3, IAM, Storage Credential, External Location, Catalog, Schema) 생성 여부"
  default     = true
}

locals {
  prefix          = var.prefix
  uc_prefix       = replace(var.prefix, "-", "_")
  uc_catalog_name = "${local.uc_prefix}_catalog"
  uc_schema_name  = "${local.uc_prefix}_schema"
  normalized_deployment_name = (
    var.deployment_name != null ? trimspace(var.deployment_name) : ""
  ) != "" ? trimspace(var.deployment_name) : null
  effective_deployment_name = var.deployment_name_prefix_enabled ? local.normalized_deployment_name : null
  tags = merge(
    {
      Owner       = var.user_name
      Environment = var.env_name
    },
    var.tags
  )
}
