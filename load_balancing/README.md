# 다중 VPC 간 Load Balancing 구성

## 선행 실습

### 필수 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## Samsung Cloud Platform 실습 환경 배포

**&#128906; 사용자 변수 입력 (\load_balancing\variables.tf)**

```hcl
variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "x.x.x.x"                           # 수강자 PC의 Public IP 주소 입력
}
```

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
cd C:\scpv2advance\advance_networking\load_balancing\
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

- **Firewall**

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|VPC1 IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|VPC1 IGW|10.1.1.110, 10.1.1.111|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Terraform|VPC2 IGW|10.2.1.0/24|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|

- **Security Group**

|Deployment|Security Group|Direction|Target Address   Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|User Add|bastionSG|Outbound|cewebSG|TCP 22|SSH outbound to ceweb vm|
|User Add|bastionSG|Outbound|bbwebSG|TCP 22|SSH outbound to bbweb vm|
|||||||
|Terraform|cewebSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|cewebSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|User Add|cewebSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|||||||
|Terraform|bbwebSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bbwebSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|User Add|bbwebSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|

## Load Balancer용 Public IP 예약

- 구분 : Internet Gateway

## Public Domian Name 확인

- Public Domain Name: '[과정소개](https://github.com/SCPv2/advance_introduction)'에서 등록한 도메인명
- Hosted Zone       : '[과정소개](https://github.com/SCPv2/advance_introduction)'에서 등록한 도메인명
- www               : A 레코드, 바로 앞에서 만든 Public IP, 300

## VPC1과 VPC2에 VPC Peering 생성

- VPC Peering명 : cepeering12  
- 요청 VPC      : VPC1  
- 승인 VPC      : VPC2  
- 규칙          :  
{출발지       : 요청 VPC, 목적지        : 10.2.1.0/24}  
{출발지       : 승인 VPC, 목적지        : 10.1.1.0/24}

## 서버에 애플리케이션 배포

**&#128906; Bastion Host에 RDP 접속 후 cewebvm111r, bbwebvm211r에 SSH 접속**

**&#128906; cewebvm111r(10.1.1.111)에서 작업 수행**

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/web-server/
sudo bash ceweb_install_web_server.sh
```

**&#128906; bbwebvm211r에서 작업 수행**

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/web-server/
sudo bash bbweb_install_web_server.sh
```

## ceweb Load Balancer 생성

- Load Balancer명: ceweblb
- 서비스 구분 :  L7
- VPC : VPC1
- Service Subnet : Subnet11
- Sevice IP      : 10.1.1.100
- Public NAT IP  : 사용

- Firewall 사용   : 사용
- Firewall 로그 저장 여부 : 사용

## ceweb LB 서버 그룹 생성

- LB 서버 그룹명 : ceweblbgrp
- VPC           : VPC1
- Service Subnet : Subnet11
- 부하 분산 : Round Robin
- 프로토콜 : TCP
- LB 헬스 체크 : HTTP_Default_Port80

- 연결된 자원 : cewebvm111r
- 가중치 : 1

## bbweb LB 서버 그룹 생성

- LB 서버 그룹명 : bbweblbgrp
- VPC           : VPC1
- Service Subnet : Subnet11
- 부하 분산 : Round Robin
- 프로토콜 : TCP
- LB 헬스 체크 : HTTP_Default_Port80

- 연결된 자원 :  10.2.1.211     # bbwebvm211r의 IP 주소
- 가중치 : 1

## ceweb Listener 생성

- Listener명 : celistener
- 프로토콜 : TCP
- 서비스 포트 : 80
- LB 서버 그룹 : celbgrp
- 세션 유지 시간 : 120초

- 지속성 : 소스 IP
- Insert Client IP : 미사용

**&#128906; 통신 제어 규칙 검토 및 새규칙 추가**

- **Firewall**

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|VPC1 IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|VPC1 IGW|10.1.1.110, 10.1.1.111|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|New|VPC1 IGW|Your Public IP|10.1.1.100(Service IP)|TCP 80|Allow|Inbound|클라이언트 → LB 연결|
|||||||||
|Terraform|VPC2 IGW|10.2.1.0/24|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|New|VPC2 IGW|Your Public IP|10.2.1.211(bbwebvm211r)|TCP 80|Allow|Inbound|HTTP inbound from your pc to bbweb vm|
|||||||||
|New|Load Balancer|Your Public IP|10.1.1.100(Service IP)|TCP 80|Allow|Outbound|클라이언트 → LB 연결|
|New|Load Balancer|LB Source NAT IP|10.1.1.111(cewebvm111r IP),10.2.1.211(bbwebvm211r IP)|TCP 80|Allow|Inbound|LB → 멤버 연결|
|New|Load Balancer|LB 헬스 체크 IP|10.1.1.111(cewebvm111r IP),10.2.1.211(bbwebvm211r IP)|TCP 80|Allow|Inbound|LB → 멤버 헬스 체크|

- **Security Group**

|Deployment|Security Group|Direction|Target Address   Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|User Add|bastionSG|Outbound|cewebSG|TCP 22|SSH outbound to ceweb vm|
|User Add|bastionSG|Outbound|bbwebSG|TCP 22|SSH outbound to bbweb vm|
|||||||
|Terraform|cewebSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|cewebSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|User Add|cewebSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|New|cewebSG|Inbound|LB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|New|cewebSG|Inbound|LB 헬스 체크 IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|||||||
|Terraform|bbwebSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bbwebSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|User Add|bbwebSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|New|bbwebSG|Inbound|LB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|New|bbwebSG|Inbound|LB 헬스 체크 IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|New|bbwebSG|Inbound|Your Public IP|TCP 80|HTTP inbound from your pc to bbweb vm|

## bbwebvm211r(10.2.1.1) 서버에서 테스트

```bash

cd /home/rocky/ceweb/artist/bbweb/
vi index_lb.html

 :/CREATIVE ENERGY   # 복사해서 붙여넣지 말고, 직접 한자씩 타이핑하고 엔터를 누르면 문자열을 찾을 수 있습니다. "CREATIVE ENERGY"를 다른 문자열로 변경하고 브라우저를 새로고침합니다.
 ```

## 자원 삭제

### Load Balancer 삭제

### VPC Peering 삭제

### Public IP 삭제

### 자동 배포 자원 삭제

```bash
cd C:\scpv2advance\advance_networking\vpn\scp_deployment
terraform destroy --auto-approve
```
