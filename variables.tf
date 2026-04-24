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

variable "enable_backend_private_link" {
  type        = bool
  description = "true면 Backend Private Link(Workspace REST + SCC Relay VPC endpoints, Private Access Settings)를 생성합니다. Databricks Enterprise tier 필요."
  default     = false
}

variable "workspace_vpce_service_names" {
  type        = map(string)
  description = "Region별 Databricks Workspace(REST) VPC endpoint service name. 공식 값은 https://docs.databricks.com/aws/en/resources/ip-domain-region#privatelink 참조."
  default = {
    "ap-northeast-1" = "com.amazonaws.vpce.ap-northeast-1.vpce-svc-02691fd610d24fd64"
    "ap-northeast-2" = "com.amazonaws.vpce.ap-northeast-2.vpce-svc-0babb9bde64f34d7e"
    "eu-central-1"   = "com.amazonaws.vpce.eu-central-1.vpce-svc-081f78503812597f7"
    "eu-west-1"      = "com.amazonaws.vpce.eu-west-1.vpce-svc-0da6ebf1461278016"
    "us-east-1"      = "com.amazonaws.vpce.us-east-1.vpce-svc-09143d1e626de2f04"
    "us-east-2"      = "com.amazonaws.vpce.us-east-2.vpce-svc-041dc2b4d7796b8d3"
    "us-west-2"      = "com.amazonaws.vpce.us-west-2.vpce-svc-0129f463fcfbc46c5"
  }
}

variable "relay_vpce_service_names" {
  type        = map(string)
  description = "Region별 Databricks SCC Relay VPC endpoint service name. 공식 값은 https://docs.databricks.com/aws/en/resources/ip-domain-region#privatelink 참조."
  default = {
    "ap-northeast-1" = "com.amazonaws.vpce.ap-northeast-1.vpce-svc-02aa633bda3edbec0"
    "ap-northeast-2" = "com.amazonaws.vpce.ap-northeast-2.vpce-svc-0dc0e98a5800db5c4"
    "eu-central-1"   = "com.amazonaws.vpce.eu-central-1.vpce-svc-08e5dfca9572c85c4"
    "eu-west-1"      = "com.amazonaws.vpce.eu-west-1.vpce-svc-09b4eb2bc775f4e8c"
    "us-east-1"      = "com.amazonaws.vpce.us-east-1.vpce-svc-00018a8c3ff62ffdf"
    "us-east-2"      = "com.amazonaws.vpce.us-east-2.vpce-svc-090a8fab0d73e39a6"
    "us-west-2"      = "com.amazonaws.vpce.us-west-2.vpce-svc-0158114c0c730c3bb"
  }
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
