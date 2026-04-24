# databricks-poc-deployment

Databricks on AWS 환경을 Terraform으로 배포하기 위한 PoC 예제입니다.  
별도 VPC를 만들고, Databricks에서 필요한 리소스를 연동/관리할 수 있도록 구성합니다.

## 이 저장소로 생성되는 주요 리소스

### 기본 인프라
- AWS VPC (public/private subnet, NAT gateway, VPC endpoint 포함)
- Databricks MWS Network
- Cross-account IAM Role 및 정책
- Root S3 Bucket 및 bucket policy
- Databricks Workspace

### Unity Catalog (`enable_unity_catalog = true` 시)
- Unity Catalog용 S3 Bucket (버저닝, 암호화, 퍼블릭 차단 적용)
- Unity Catalog용 IAM Role (Databricks UC Master Role 신뢰 + Self-assume)
- IAM Policy (S3 CRUD + sts:AssumeRole)
- Metastore Assignment (워크스페이스에 Metastore 할당)
- Storage Credential (IAM Role 기반)
- External Location (S3 경로 매핑)
- Catalog (`{prefix}_catalog` 형식, 예: `mycompany001_poc_catalog`)
- Schema (`{prefix}_db` 형식, 예: `mycompany001_poc_db`)

## 사전 준비

- AWS 계정 및 Terraform 실행 권한
- AWS CLI 설치 및 로그인 완료 상태 (`aws configure` 또는 `aws sso login`)
- AWS 인증 확인 가능 상태 (`aws sts get-caller-identity` 성공)
- Databricks Account Admin 권한이 있는 Service Principal
- 아래 값 준비
  - `databricks_account_id`
  - `client_id`
  - `client_secret`
  - `user_name`
  - `region`
  - `prefix`
  - `deployment_name_prefix_enabled`
  - `deployment_name` (선택)
  - `cidr_block`
  - `metastore_id` (Unity Catalog 사용 시 — 아래 "Metastore ID 확인 방법" 참조. **해당 region에 metastore가 없으면 빈 문자열 `""`로 두면 신규 생성**)
  - `enable_unity_catalog` (기본값: `true`)

### Metastore ID 확인 방법

Databricks Account는 **region당 Metastore 1개** 제약이 있습니다. 배포하려는 region에 Metastore가 이미 있는지에 따라 다음과 같이 설정합니다.

| 상태 | `metastore_id` 값 | 동작 |
|---|---|---|
| 해당 region에 Metastore **이미 있음** | 기존 Metastore ID 입력 | 기존 Metastore에 워크스페이스 assignment만 수행 |
| 해당 region에 Metastore **없음** | 빈 문자열 `""` | 신규 Metastore + S3 root storage를 생성하고 assignment |

> ⚠️ region에 이미 Metastore가 있는데 `""`로 두면 중복 생성 시도로 실패합니다. 먼저 아래 방법으로 확인하세요.

Metastore ID 확인 방법:

**방법 1. Databricks Account Console**
1. https://accounts.cloud.databricks.com 접속
2. Data 탭 → Metastores 선택
3. 해당 region의 Metastore 선택 → Metastore ID 복사

**방법 2. API로 조회**
```bash
# Service Principal 토큰 발급
TOKEN=$(curl -s -X POST "https://accounts.cloud.databricks.com/oidc/accounts/<ACCOUNT_ID>/v1/token" \
  -d "grant_type=client_credentials&client_id=<CLIENT_ID>&client_secret=<CLIENT_SECRET>&scope=all-apis" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Metastore 목록 조회
curl -s "https://accounts.cloud.databricks.com/api/2.0/accounts/<ACCOUNT_ID>/metastores" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

## Terraform 실행 방법 (방법 2, 상세)

1. Terraform 설치 (없다면)

- macOS (Homebrew)

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

- Windows (Chocolatey)

```powershell
choco install terraform
```

- Ubuntu / Debian

```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
```

- 설치 확인

```bash
terraform -version
```

2. 저장소 클론

```bash
git clone https://github.com/hanmilLee/databricks-poc-deployment.git
cd databricks-poc-deployment
```

3. `terraform.tfvars` 값 수정

저장소에 포함된 `terraform.tfvars.example`을 복사해 `terraform.tfvars`로 만들고 값을 채워주세요. Terraform은 `terraform.tfvars`를 자동으로 읽기 때문에 `-var-file` 플래그가 필요 없습니다.

```bash
cp terraform.tfvars.example terraform.tfvars
# 이후 터미널 편집기로 값 수정
```

아래 항목을 실제 값으로 바꿔주세요.
이 프로젝트는 AWS Provider 기본 자격 증명 체인(예: AWS CLI 로그인 세션, `~/.aws/credentials`)을 사용하므로 `aws_access_key_id`/`aws_secret_access_key`는 `terraform.tfvars`에 넣지 않습니다.

```hcl
env_name                       = "databricks"
user_name                      = "[firstname.lastname]"        # example. "hanmil.lee"
region                         = "ap-northeast-2"              # 사용될 region
prefix                         = "mycompany001-poc"            # 사용될 databricks workspace name
deployment_name_prefix_enabled = false                         # Salesforce상에서 prefix 가 enable 된 경우 true, 아니면 false
deployment_name                = null                          # deployment_name_prefix_enabled = true인 경우, workspace url prefix 입력
databricks_account_id          = "[databricks account id]"     # "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_id                      = "[service principal client id]"
client_secret                  = "[service principal secret]"
cidr_block                     = "[vpc cidr block]"            # example. "10.10.0.0/16"
metastore_id                   = "[metastore id]"              # Unity Catalog용 Metastore ID
enable_unity_catalog           = true                          # false로 설정 시 UC 리소스 미생성
```

`deployment_name_prefix_enabled = true`로 설정한 경우에만 `deployment_name` 값을 넣어주세요.

4. AWS 인증 상태 확인

```bash
aws sts get-caller-identity
```

5. Terraform 명령 실행

```bash
terraform init
terraform plan
terraform apply
```

6. 배포 결과 확인

```bash
terraform output databricks_host
terraform output databricks_token

# Unity Catalog 리소스 확인
terraform output uc_catalog_name
terraform output uc_external_location_url
terraform output uc_storage_credential_name
```

7. Unity Catalog 등록 확인

배포 완료 후 Databricks 워크스페이스에서 다음을 확인합니다:

- **Catalog** 메뉴 → 생성된 카탈로그 (`{prefix}_catalog`) 확인
- **Catalog** → 카탈로그 선택 → 스키마 (`{prefix}_db`) 확인
- **Catalog** → External Data → **Storage Credentials** → `{prefix}-uc-credential` 확인
- **Catalog** → External Data → **External Locations** → `{prefix}-uc-external-location` 확인

8. 리소스 삭제

```bash
terraform destroy
```

> **Tip**: 재배포 시 이전 워크스페이스가 `RUNNING` 또는 `BANNED` 상태로 남아있으면 `mws_credentials`/`mws_networks`/`mws_storage_configurations` destroy가 막힙니다. Account Console에서 워크스페이스 먼저 삭제 후 `terraform destroy` 실행하세요.

## Unity Catalog 없이 배포하기

워크스페이스만 배포하고 Unity Catalog 리소스는 생성하지 않으려면:

```hcl
enable_unity_catalog = false
```

이 경우 S3(UC용), IAM Role(UC용), Storage Credential, External Location, Catalog, Schema가 생성되지 않습니다.

## 사용된 Provider 버전

| Provider | Version |
|----------|---------|
| Terraform | >= 1.6.0, < 2.0.0 |
| hashicorp/aws | ~> 5.80.0 |
| databricks/databricks | ~> 1.111.0 |
| hashicorp/time | ~> 0.13.0 |
| terraform-aws-modules/vpc/aws | 5.16.0 |

## Databricks 전용 VPC 및 리소스 셋업 방법 선택 가이드

Databricks 전용 별도 VPC를 생성하고, 관련 리소스를 Databricks에서 관리하도록 셋업하려면 아래 3가지 방법 중에서 선택할 수 있습니다.

### 방법 1. AWS IAM 임시 위임 (가장 편리, 약 10분 내 구성)

- Databricks에서 안내하는 간편한 인프라 셋업 방식
- 링크: <https://www.databricks.com/kr/blog/databricks-and-aws-partner-simplify-infrastructure-setup>

### 방법 2. Terraform 활용 (이 저장소 사용)

- IaC 기반으로 재현 가능한 배포가 필요할 때 적합
- 이 저장소 코드로 네트워크/IAM/스토리지/워크스페이스 + Unity Catalog를 자동 구성

### 방법 3. 수작업 배포

- 기존 VPC를 반드시 사용해야 하거나, 준수해야 할 네트워크/보안 정책이 엄격한 경우 권장
- 링크: <https://yubin-cho.gitbook.io/databricks>
