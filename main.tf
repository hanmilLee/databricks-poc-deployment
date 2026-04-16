terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.111.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.0"
    }
  }
}

provider "aws" {
  region = var.region
}

// initialize provider in "MWS" mode to provision new workspace
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  client_id     = var.client_id
  client_secret = var.client_secret
  account_id    = var.databricks_account_id
}

// workspace-level provider for Unity Catalog resources
provider "databricks" {
  alias         = "workspace"
  host          = databricks_mws_workspaces.this.workspace_url
  client_id     = var.client_id
  client_secret = var.client_secret
}
