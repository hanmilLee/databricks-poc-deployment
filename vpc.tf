###############################################################################
# 워크스페이스 서브넷 AZ 선택
#   인터페이스 VPC 엔드포인트(STS/Kinesis + Databricks REST/relay)는 AZ마다
#   지원 여부가 다르고, AZ 이름↔물리 AZ 매핑도 계정마다 다릅니다. 지원하지 않는
#   AZ에 서브넷을 두면 CreateVpcEndpoint가 "does not support the availability
#   zone of the subnet"로 실패하므로, 모든 엔드포인트가 지원하는 AZ 교집합에서
#   2개를 선택합니다. var.availability_zones로 수동 지정도 가능합니다.
###############################################################################

data "aws_vpc_endpoint_service" "sts" {
  service_name = "com.amazonaws.${var.region}.sts"
}

data "aws_vpc_endpoint_service" "kinesis" {
  service_name = "com.amazonaws.${var.region}.kinesis-streams"
}

data "aws_vpc_endpoint_service" "workspace" {
  count        = local.enable_privatelink ? 1 : 0
  service_name = local.workspace_vpce_service_name
}

data "aws_vpc_endpoint_service" "relay" {
  count        = local.enable_privatelink ? 1 : 0
  service_name = local.relay_vpce_service_name
}

locals {
  # 각 인터페이스 엔드포인트가 지원하는 AZ 집합 (PrivateLink 사용 시 Databricks 서비스도 포함)
  endpoint_az_sets = concat(
    [
      toset(data.aws_vpc_endpoint_service.sts.availability_zones),
      toset(data.aws_vpc_endpoint_service.kinesis.availability_zones),
    ],
    local.enable_privatelink ? [
      toset(data.aws_vpc_endpoint_service.workspace[0].availability_zones),
      toset(data.aws_vpc_endpoint_service.relay[0].availability_zones),
    ] : []
  )
  # 모든 엔드포인트가 지원하는 AZ 교집합에서 앞 2개 (var.availability_zones로 수동 override 가능)
  supported_azs = sort(tolist(setintersection(local.endpoint_az_sets...)))
  effective_azs = var.availability_zones != null ? var.availability_zones : slice(local.supported_azs, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = local.prefix
  cidr = var.cidr_block
  azs  = local.effective_azs
  tags = local.tags

  enable_dns_hostnames = true
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.enable_nat_gateway
  create_igw           = var.enable_nat_gateway

  # Option 2(enable_nat_gateway = false)는 공용 egress 경로를 두지 않으므로 public subnet을 생성하지 않습니다.
  public_subnets  = var.enable_nat_gateway ? [cidrsubnet(var.cidr_block, 3, 0), cidrsubnet(var.cidr_block, 3, 2)] : []
  private_subnets = [cidrsubnet(var.cidr_block, 3, 1), cidrsubnet(var.cidr_block, 3, 3)]

  manage_default_security_group = true
  default_security_group_name   = "${local.prefix}-sg"

  default_security_group_egress = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 6666
      to_port     = 6666
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8443
      to_port     = 8444
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8445
      to_port     = 8451
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      self      = "true"
      from_port = 0
      to_port   = 65535
      protocol  = "tcp"
    },
    {
      self      = "true"
      from_port = 0
      to_port   = 65535
      protocol  = "udp"
    }
  ]

  default_security_group_ingress = [
    {
      self      = "true"
      from_port = 0
      to_port   = 65535
      protocol  = "tcp"
    },
    {
      self      = "true"
      from_port = 0
      to_port   = 65535
      protocol  = "udp"
    }
  ]
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.16.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids
      ])
      tags = merge(local.tags, {
        Name = "${local.prefix}-s3-vpc-endpoint"
      })
    },
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = merge(local.tags, {
        Name = "${local.prefix}-sts-vpc-endpoint"
      })
    },
    kinesis-streams = {
      service             = "kinesis-streams"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = merge(local.tags, {
        Name = "${local.prefix}-kinesis-vpc-endpoint"
      })
    },
  }

  tags = local.tags
}

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${local.prefix}-network"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id

  dynamic "vpc_endpoints" {
    for_each = local.enable_privatelink ? [1] : []
    content {
      dataplane_relay = [databricks_mws_vpc_endpoint.backend_relay[0].vpc_endpoint_id]
      rest_api        = [databricks_mws_vpc_endpoint.backend_rest[0].vpc_endpoint_id]
    }
  }
}
