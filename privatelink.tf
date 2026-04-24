###############################################################################
# Backend Private Link (optional, enable_backend_private_link = true)
#   - Workspace REST API VPC endpoint
#   - Secure Cluster Connectivity (SCC) Relay VPC endpoint
#   - databricks_mws_vpc_endpoint (x2) + databricks_mws_private_access_settings
#
# 참조: https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/aws-private-link-workspace
###############################################################################

locals {
  enable_privatelink          = var.enable_backend_private_link
  workspace_vpce_service_name = lookup(var.workspace_vpce_service_names, var.region, null)
  relay_vpce_service_name     = lookup(var.relay_vpce_service_names, var.region, null)
}

resource "aws_security_group" "privatelink" {
  count       = local.enable_privatelink ? 1 : 0
  name        = "${local.prefix}-privatelink-sg"
  description = "Databricks Backend PrivateLink VPC endpoint SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Databricks REST API (HTTPS) from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  ingress {
    description = "Databricks SCC Relay from VPC"
    from_port   = 6666
    to_port     = 6666
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.prefix}-privatelink-sg"
  })
}

resource "aws_vpc_endpoint" "backend_rest" {
  count               = local.enable_privatelink ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = local.workspace_vpce_service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink[0].id]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.prefix}-backend-rest-vpce"
  })

  lifecycle {
    precondition {
      condition     = local.workspace_vpce_service_name != null
      error_message = "workspace_vpce_service_names map에 현재 region(${var.region}) 항목이 없습니다. variables.tf의 기본값 또는 terraform.tfvars에 해당 region 값을 추가하세요."
    }
  }
}

resource "aws_vpc_endpoint" "backend_relay" {
  count               = local.enable_privatelink ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = local.relay_vpce_service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink[0].id]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.prefix}-backend-relay-vpce"
  })

  lifecycle {
    precondition {
      condition     = local.relay_vpce_service_name != null
      error_message = "relay_vpce_service_names map에 현재 region(${var.region}) 항목이 없습니다. variables.tf의 기본값 또는 terraform.tfvars에 해당 region 값을 추가하세요."
    }
  }
}

resource "databricks_mws_vpc_endpoint" "backend_rest" {
  count               = local.enable_privatelink ? 1 : 0
  provider            = databricks.mws
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = aws_vpc_endpoint.backend_rest[0].id
  vpc_endpoint_name   = "${local.prefix}-backend-rest"
  region              = var.region
  depends_on          = [aws_vpc_endpoint.backend_rest]
}

resource "databricks_mws_vpc_endpoint" "backend_relay" {
  count               = local.enable_privatelink ? 1 : 0
  provider            = databricks.mws
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = aws_vpc_endpoint.backend_relay[0].id
  vpc_endpoint_name   = "${local.prefix}-backend-relay"
  region              = var.region
  depends_on          = [aws_vpc_endpoint.backend_relay]
}

resource "databricks_mws_private_access_settings" "this" {
  count                        = local.enable_privatelink ? 1 : 0
  provider                     = databricks.mws
  account_id                   = var.databricks_account_id
  private_access_settings_name = "${local.prefix}-pas"
  region                       = var.region
  public_access_enabled        = true
}

output "backend_private_link_enabled" {
  value       = local.enable_privatelink
  description = "Backend Private Link 활성화 여부"
}

output "backend_rest_vpc_endpoint_id" {
  value       = local.enable_privatelink ? aws_vpc_endpoint.backend_rest[0].id : null
  description = "AWS VPC endpoint ID for Databricks Workspace REST API"
}

output "backend_relay_vpc_endpoint_id" {
  value       = local.enable_privatelink ? aws_vpc_endpoint.backend_relay[0].id : null
  description = "AWS VPC endpoint ID for Databricks SCC Relay"
}

output "private_access_settings_id" {
  value       = local.enable_privatelink ? databricks_mws_private_access_settings.this[0].private_access_settings_id : null
  description = "Databricks Private Access Settings ID"
}
