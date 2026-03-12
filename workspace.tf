resource "databricks_mws_workspaces" "this" {
  provider        = databricks.mws
  account_id      = var.databricks_account_id
  aws_region      = var.region
  workspace_name  = local.prefix
  deployment_name = local.effective_deployment_name

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  lifecycle {
    precondition {
      condition     = !var.deployment_name_prefix_enabled || local.normalized_deployment_name != null
      error_message = "deployment_name_prefix_enabled=true 인 경우 deployment_name 값을 입력해야 합니다."
    }

    precondition {
      condition     = var.deployment_name_prefix_enabled || local.normalized_deployment_name == null
      error_message = "계정에서 deployment name prefix가 비활성화된 경우 deployment_name을 비워두세요(null 또는 빈값)."
    }
  }

  token {
    comment = "Terraform"
  }
}

output "databricks_host" {
  value = databricks_mws_workspaces.this.workspace_url
}

output "databricks_token" {
  value     = databricks_mws_workspaces.this.token[0].token_value
  sensitive = true
}
