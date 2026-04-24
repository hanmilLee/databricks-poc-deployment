###############################################################################
# Unity Catalog - S3 Bucket
###############################################################################

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "uc_bucket" {
  count         = var.enable_unity_catalog ? 1 : 0
  bucket        = "${local.prefix}-uc-catalog"
  force_destroy = true
  tags = merge(local.tags, {
    Name = "${local.prefix}-uc-catalog"
  })
}

resource "aws_s3_bucket_ownership_controls" "uc_bucket" {
  count  = var.enable_unity_catalog ? 1 : 0
  bucket = aws_s3_bucket.uc_bucket[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uc_bucket" {
  count  = var.enable_unity_catalog ? 1 : 0
  bucket = aws_s3_bucket.uc_bucket[0].bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uc_bucket" {
  count                   = var.enable_unity_catalog ? 1 : 0
  bucket                  = aws_s3_bucket.uc_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uc_bucket" {
  count  = var.enable_unity_catalog ? 1 : 0
  bucket = aws_s3_bucket.uc_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "uc_bucket" {
  count  = var.enable_unity_catalog ? 1 : 0
  bucket = aws_s3_bucket.uc_bucket[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.uc_role[0].arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          aws_s3_bucket.uc_bucket[0].arn,
          "${aws_s3_bucket.uc_bucket[0].arn}/*"
        ]
      }
    ]
  })
}

###############################################################################
# Unity Catalog - Metastore (create if not provided) + Assignment
###############################################################################

locals {
  uc_role_name           = "${local.prefix}-uc-role"
  create_metastore       = var.enable_unity_catalog && var.metastore_id == ""
  effective_metastore_id = local.create_metastore ? databricks_metastore.this[0].metastore_id : var.metastore_id
}

resource "aws_s3_bucket" "metastore_bucket" {
  count         = local.create_metastore ? 1 : 0
  bucket        = "${local.prefix}-metastore"
  force_destroy = true
  tags = merge(local.tags, {
    Name = "${local.prefix}-metastore"
  })
}

resource "aws_s3_bucket_public_access_block" "metastore_bucket" {
  count                   = local.create_metastore ? 1 : 0
  bucket                  = aws_s3_bucket.metastore_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "metastore_bucket" {
  count  = local.create_metastore ? 1 : 0
  bucket = aws_s3_bucket.metastore_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "databricks_metastore" "this" {
  count         = local.create_metastore ? 1 : 0
  provider      = databricks.mws
  name          = "${local.prefix}-metastore"
  region        = var.region
  storage_root  = "s3://${aws_s3_bucket.metastore_bucket[0].bucket}"
  force_destroy = true
}

resource "databricks_metastore_assignment" "this" {
  count        = var.enable_unity_catalog ? 1 : 0
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  metastore_id = local.effective_metastore_id
}

###############################################################################
# Unity Catalog - IAM Role + Storage Credential (official self-assume pattern)
###############################################################################

resource "databricks_storage_credential" "this" {
  count    = var.enable_unity_catalog ? 1 : 0
  provider = databricks.workspace

  name = "${local.prefix}-uc-credential"
  aws_iam_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.uc_role_name}"
  }
  comment         = "Unity Catalog storage credential for PoC"
  skip_validation = true
  depends_on      = [databricks_metastore_assignment.this]
}

data "databricks_aws_unity_catalog_assume_role_policy" "this" {
  count          = var.enable_unity_catalog ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  role_name      = local.uc_role_name
  external_id    = databricks_storage_credential.this[0].aws_iam_role[0].external_id
}

resource "aws_iam_role" "uc_role" {
  count                = var.enable_unity_catalog ? 1 : 0
  name                 = local.uc_role_name
  assume_role_policy   = data.databricks_aws_unity_catalog_assume_role_policy.this[0].json
  max_session_duration = 43200
  tags                 = local.tags
}

resource "aws_iam_role_policy" "uc_policy" {
  count = var.enable_unity_catalog ? 1 : 0
  name  = "${local.prefix}-uc-policy"
  role  = aws_iam_role.uc_role[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = concat(
          [aws_s3_bucket.uc_bucket[0].arn, "${aws_s3_bucket.uc_bucket[0].arn}/*"],
          local.create_metastore ? [aws_s3_bucket.metastore_bucket[0].arn, "${aws_s3_bucket.metastore_bucket[0].arn}/*"] : []
        )
      },
      {
        Sid    = "SelfAssumeRole"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = [
          aws_iam_role.uc_role[0].arn
        ]
      }
    ]
  })
}

resource "time_sleep" "uc_iam_propagation" {
  count = var.enable_unity_catalog ? 1 : 0
  depends_on = [
    aws_iam_role.uc_role[0],
    aws_iam_role_policy.uc_policy[0],
    aws_s3_bucket_policy.uc_bucket[0],
  ]

  create_duration = "60s"
}

###############################################################################
# Unity Catalog - External Location + Catalog + Schema
###############################################################################

resource "databricks_external_location" "this" {
  count           = var.enable_unity_catalog ? 1 : 0
  provider        = databricks.workspace
  name            = "${local.prefix}-uc-external-location"
  url             = "s3://${aws_s3_bucket.uc_bucket[0].bucket}"
  credential_name = databricks_storage_credential.this[0].name
  comment         = "Unity Catalog external location for PoC"
  skip_validation = true
  depends_on      = [time_sleep.uc_iam_propagation]
}

resource "databricks_catalog" "this" {
  count        = var.enable_unity_catalog ? 1 : 0
  provider     = databricks.workspace
  name         = local.uc_catalog_name
  storage_root = "s3://${aws_s3_bucket.uc_bucket[0].bucket}/${local.uc_catalog_name}"
  comment      = "PoC catalog created by Terraform"
  depends_on   = [databricks_external_location.this]
}

resource "databricks_schema" "this" {
  count        = var.enable_unity_catalog ? 1 : 0
  provider     = databricks.workspace
  catalog_name = databricks_catalog.this[0].name
  name         = local.uc_schema_name
  comment      = "Default schema created by Terraform"
}

###############################################################################
# Outputs
###############################################################################

output "uc_catalog_name" {
  value       = var.enable_unity_catalog ? databricks_catalog.this[0].name : null
  description = "Name of the created Unity Catalog"
}

output "uc_external_location_url" {
  value       = var.enable_unity_catalog ? databricks_external_location.this[0].url : null
  description = "S3 URL of the Unity Catalog external location"
}

output "uc_storage_credential_name" {
  value       = var.enable_unity_catalog ? databricks_storage_credential.this[0].name : null
  description = "Name of the Unity Catalog storage credential"
}
