# databricks-poc-deployment

Databricks on AWS 환경을 Terraform으로 배포하기 위한 PoC 예제입니다.  
별도 VPC를 만들고, Databricks에서 필요한 리소스를 연동/관리할 수 있도록 구성합니다.

## 이 저장소로 생성되는 주요 리소스

- AWS VPC (public/private subnet, NAT gateway, VPC endpoint 포함)
- Databricks MWS Network
- Cross-account IAM Role 및 정책
- Root S3 Bucket 및 bucket policy
- Databricks Workspace

## 사전 준비

- AWS 계정 및 Terraform 실행 권한
- Databricks Account Admin 권한이 있는 Service Principal
- 아래 값 준비
  - `databricks_account_id`
  - `client_id`
  - `client_secret`
  - `user_name`
  - `region`
  - `cidr_block`

## Terraform 실행 방법 (방법 2)

1. `input.tfvars` 값을 환경에 맞게 수정
2. 아래 순서로 실행

```bash
terraform init
terraform plan -var-file="input.tfvars"
terraform apply -var-file="input.tfvars"
```

3. 배포 결과 확인

```bash
terraform output databricks_host
terraform output databricks_token
```

4. 리소스 삭제

```bash
terraform destroy -var-file="input.tfvars"
```

## Databricks 전용 VPC 및 리소스 셋업 방법 선택 가이드

Databricks 전용 별도 VPC를 생성하고, 관련 리소스를 Databricks에서 관리하도록 셋업하려면 아래 3가지 방법 중에서 선택할 수 있습니다.

### 방법 1. AWS IAM 임시 위임 (가장 편리, 약 10분 내 구성)

- Databricks에서 안내하는 간편한 인프라 셋업 방식
- 링크: <https://www.databricks.com/kr/blog/databricks-and-aws-partner-simplify-infrastructure-setup>

### 방법 2. Terraform 활용 (이 저장소 사용)

- IaC 기반으로 재현 가능한 배포가 필요할 때 적합
- 이 저장소 코드로 네트워크/IAM/스토리지/워크스페이스를 자동 구성

### 방법 3. 수작업 배포

- 기존 VPC를 반드시 사용해야 하거나, 준수해야 할 네트워크/보안 정책이 엄격한 경우 권장
- 링크: <https://yubin-cho.gitbook.io/databricks>

