# VPC Peering과 Transit Gateway 구성

## Samsung Cloud Platform 실습 환경 배포

**&#128906; 사용자 변수 입력** (\advance_networking\vpc_peering_transit_gateway\variables.tf)

```hcl
variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "x.x.x.x"                 🠈 수강자 PC의 Public IP 주소 입력
}
```

**&#128906; Terraform 자원 배포 템플릿 실행** (\advance_networking\vpc_peering_transit_gateway)

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## 환경 검토

- Architectuer Diagram

- VPC CIDR
- Subnet CIDR
- Virtual Server OS, Public IP, Private IP
- Firewall 규칙
- Security Group 규칙

## VPC Peering 구성

### VPC1과 VPC2에 VPC Peering 생성

- VPC Peering명 : `cepeering12`  

- 요청 VPC      : VPC1  
- 승인 VPC      : VPC2  
- 규칙          :  
{출발지       : 요청 VPC, 목적지        : `10.2.1.0/24`}  
{출발지       : 승인 VPC, 목적지        : `10.1.1.0/24`}

### VPC2과 VPC3에 VPC Peering 생성

- VPC Peering명 : `cepeering23`  

- 요청 VPC      : VPC2  
- 승인 VPC      : VPC3  
- 규칙          :  
{출발지       : 요청 VPC, 목적지        : `10.3.1.0/24`}  
{출발지       : 승인 VPC, 목적지        : `10.2.1.0/24`}

**&#128906; 통신 제어 규칙 검토 및 새규칙 추가**

- **Firewall**

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|VPC1 IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|VPC1 IGW|10.1.1.110|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Terraform|VPC2 IGW|10.2.1.211|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Terraform|VPC3 IGW|10.3.1.31|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|

- **Security Group**

|Deployment|Security Group|Direction|Target Address   Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|primarySG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terraform|primarySG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|primarySG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|User Add|primarySG|Outbound|secondarySG|TCP 22|SSH outbound to vm in VPC2|
|User Add|primarySG|Outbound|tertiarySG|TCP 22|SSH outbound to vm in VPC3|
|||||||
|Terraform|secondarySG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|secondarySG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|User Add|secondarySG|Inbound|primarySG|TCP 22|SSH inbound from vm in VPC1|
|User Add|secondarySG|Outbound|tertiarySG|TCP 22|SSH outbound to vm in VPC3|
|User Add|secondarySG|Inbound|tertiarySG|TCP 22|SSH inbound from vm in VPC3|
|||||||
|Terraform|tertiarySG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|tertiarySG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|User Add|tertiarySG|Inbound|primarySG|TCP 22|SSH inbound from vm in VPC1|
|User Add|tertiarySG|Inbound|secondarySG|TCP 22|SSH inbound from vm in VPC2|
|User Add|tertiarySG|Outbound|secondarySG|TCP 22|SSH outbound to vm in VPC2|

### VPC Peering 연결 테스트

- VPC1의 Windows VM에서 VPC2의 Linux VM에 SSH 연결 테스트

- VPC1의 Windows VM에서 VPC2를 Linux VM을 경유하여 VPC3의 Linux VM에 SSH Tunneling 연결 테스트

- VPC1의 Windows VM에서 VPC3의 Linux VM에 SSH 연결 테스트

### VPC Peering 삭제

- cepeering12 규칙 삭제 후 peering 삭제

- cepeering23 규칙 삭제 후 peering 삭제

## Transit Gateway 구성

- VPC Peering명 : `cetgw123`  

- 연결 VPC 관리  : VPC1, VPC2, VPC3  

- 규칙 :

|연결 VPC명|출발지|목적지|목적지 IP 대역|
|-----|-----|-----|-----|
|VPC1|VPC|TGW|10.2.1.0/24|  
|VPC1|VPC|TGW|10.3.1.0/24|  
|VPC1|TGW|VPC|10.1.1.0/24|  
|VPC2|VPC|TGW|10.1.1.0/24|  
|VPC2|VPC|TGW|10.3.1.0/24|  
|VPC2|TGW|VPC|10.2.1.0/24|  
|VPC3|VPC|TGW|10.1.1.0/24|  
|VPC3|VPC|TGW|10.2.1.0/24|  
|VPC3|TGW|VPC|10.3.1.0/24|

### Transit Gateway 연결 테스트

- VPC1의 Windows VM에서 VPC2의 Linux VM에 SSH 연결

- VPC1의 Windows VM에서 VPC2를 Linux VM을 경유하여 VPC3의 Linux VM에 SSH Tunneling 연결 테스트

- VPC1의 Windows VM에서 VPC3의 Linux VM에 SSH 연결

- VPC1의 Windows VM에서 VPC3를 Linux VM을 경유하여 VPC2의 Linux VM에 SSH Tunneling 연결 테스트

## 자원 삭제

### Transit Gateway 삭제

- 규칙 삭제

- 연결 VPC 삭제

- Transit Gateway 삭제

### 자동 배포 자원 삭제

```bash
cd C:\scpv2advance\advance_networking\vpn\scp_deployment
terraform destroy --auto-approve
```
