# Cross VPC Load Balancing 구성

## 실습 개요

이 실습은 Samsung Cloud Platform v2에서 Cross VPC Load Balancing 아키텍처를 배포하여 다중 VPC 간 로드 밸런서 구성을 학습하고, 수동 VPC Peering 설정을 통해 네트워킹 개념을 이해하는 것을 목표로 합니다.

### 아키텍처 특징
- **Cross VPC 구성**: 2개의 독립된 VPC (VPC1: Creative Energy, VPC2: Big Boys)
- **교육적 목적**: 수동 Load Balancer 및 VPC Peering 설정을 통한 학습
- **최소 사용자 입력**: keypair_name과 user_public_ip만 필요
- **실무 시나리오**: 서로 다른 VPC의 웹 서비스를 하나의 Load Balancer로 통합

## 선행 실습

### 필수 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair 생성 및 다운로드
- 사용자 PC Public IP 확인
- Load Balancer용 Public IP 이해

### 권장 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습
- Infrastructure as Code 개념 이해

## 실습 환경 배포

**&#128906; 사용자 변수 입력 (variables.tf)**

반드시 다음 변수들을 실제 값으로 수정해야 합니다:

```hcl
# 필수 수정 항목
variable "user_public_ip" {
  default = "x.x.x.x"        # 사용자 PC의 Public IP 주소
}

variable "keypair_name" {
  default = "mykey"          # 생성한 Key Pair 이름
}
```

**💡 참고사항:**
- 이 템플릿은 교육용으로 최소한의 입력값만 요구합니다
- DNS 설정은 불필요 (IP 주소로 직접 접근)
- Load Balancer와 VPC Peering은 수동으로 설정하여 학습 효과를 극대화

**&#128906; PowerShell 자동 배포 스크립트 실행 (권장)**

```powershell
cd C:\Users\dion\.local\bin\scpv2\advance_networking\load_balancing\
.\deploy_scp_lab_resource.ps1
```

**&#128906; 수동 Terraform 명령어 실행 (대안)**

```bash
cd C:\Users\dion\.local\bin\scpv2\advance_networking\load_balancing\
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

**&#128906; 배포 진행 상황 확인**

- PowerShell 스크립트는 자동으로 master_config.json을 생성합니다
- 약 8-12분 소요됩니다 (Cross VPC 환경 구성 시간 포함)
- 각 VM에서 userdata 실행 로그는 `/var/log/userdata_*.log`에서 확인 가능

## 환경 검토

배포된 인프라를 확인하고 네트워크 구성을 이해합니다.

### Architecture Diagram
- **VPC1 (10.1.0.0/16)**: Bastion + Creative Energy Web Server
- **VPC2 (10.2.0.0/16)**: Big Boys Web Server  
- **Cross VPC Load Balancing**: VPC1의 Load Balancer가 양쪽 VPC의 서버 관리

### VPC 및 Subnet 구성
| VPC | CIDR | Subnet | 용도 |
|-----|------|--------|------|
| VPC1 | 10.1.0.0/16 | 10.1.1.0/24 | Bastion, CE Web, Load Balancer |
| VPC2 | 10.2.0.0/16 | 10.2.1.0/24 | Big Boys Web Server |

### Virtual Server 구성
| 서버명 | VPC | IP | OS | 역할 |
|--------|-----|----|----|------|
| bastionvm110w | VPC1 | 10.1.1.110 | Windows 2019 | Bastion Host |
| cewebvm111r | VPC1 | 10.1.1.111 | Rocky Linux 9 | Creative Energy 웹서버 |
| bbwebvm211r | VPC2 | 10.2.1.211 | Rocky Linux 9 | Big Boys 웹서버 |

### Firewall 규칙

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|VPC1 IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|VPC1 IGW|10.1.1.110, 10.1.1.111|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Terraform|VPC2 IGW|10.2.1.0/24|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Manual Add|VPC1 IGW|Your Public IP|10.1.1.100(Service IP)|TCP 80|Allow|Inbound|클라이언트 → LB 연결|
|Manual Add|VPC2 IGW|Your Public IP|10.2.1.211(bbwebvm211r)|TCP 80|Allow|Inbound|HTTP inbound from your pc to bbweb vm (테스트용)|

### Security Group 규칙

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Manual Add|bastionSG|Outbound|cewebSG|TCP 22|SSH outbound to ceweb vm|
|Manual Add|bastionSG|Outbound|bbwebSG|TCP 22|SSH outbound to bbweb vm|
|||||||
|Terraform|cewebSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|cewebSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Manual Add|cewebSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Manual Add|cewebSG|Inbound|LB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|Manual Add|cewebSG|Inbound|LB 헬스 체크 IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|||||||
|Terraform|bbwebSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bbwebSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Manual Add|bbwebSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Manual Add|bbwebSG|Inbound|LB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|Manual Add|bbwebSG|Inbound|LB 헬스 체크 IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|Manual Add|bbwebSG|Inbound|Your Public IP|TCP 80|HTTP inbound from your pc to bbweb vm (테스트용)|

## 서버 구성

### &#128906; VM 접속 및 Ready 파일 확인

**1. Bastion Host RDP 접속**
- Public IP를 통해 Windows RDP 접속 (3389 포트)
- terraform 실행 결과에서 Bastion Public IP 확인

**2. Linux VM들 SSH 접속 (Bastion을 통해)**
```bash
# Bastion에서 각 Linux VM으로 SSH 접속
ssh -i your-key.pem rocky@10.1.1.111  # Creative Energy 웹서버
ssh -i your-key.pem rocky@10.2.1.211  # Big Boys 웹서버
```

**3. Ready 파일 확인**
각 서버에서 설치 준비 상태 확인:
```bash
# 각 서버에서 ready 파일 확인
cat /home/rocky/z_ready2install_*

# 예시 출력:
# Web Server preparation completed: 2025-08-22
# Next step: Run installation commands manually
```

### &#128906; 웹 애플리케이션 설치

**중요**: 두 서버에 각각 다른 웹 애플리케이션을 설치합니다.

**1. Creative Energy 웹서버 설치 (cewebvm111r)**

```bash
# Creative Energy 서버 (10.1.1.111)에 SSH 접속 후
cd /home/rocky/ceweb/web-server/
sudo bash ceweb_install_web_server.sh

# 설치 완료 확인
sudo systemctl status nginx
curl http://localhost/
```

**2. Big Boys 웹서버 설치 (bbwebvm211r)**

```bash
# Big Boys 서버 (10.2.1.211)에 SSH 접속 후
cd /home/rocky/ceweb/web-server/
sudo bash bbweb_install_web_server.sh

# 설치 완료 확인
sudo systemctl status nginx
curl http://localhost/
```

### &#128906; 개별 서비스 접속 테스트

설치 완료 후 각 웹서버에 직접 접속하여 정상 작동을 확인합니다:

- **Creative Energy**: http://10.1.1.111/ (VPC1 내부)
- **Big Boys**: http://10.2.1.211/ (VPC2 내부 - 외부 접근 가능하도록 Firewall 설정 필요)

## VPC Peering 구성 (수동 설정)

Cross VPC Load Balancing을 위해 VPC 간 통신을 설정합니다.

### &#128906; VPC Peering 생성

**Samsung Cloud Platform v2 콘솔에서 수행:**

1. **VPC Peering 기본 설정:**
   - VPC Peering명: cepeering12
   - 요청 VPC: VPC1 (10.1.0.0/16)
   - 승인 VPC: VPC2 (10.2.0.0/16)

2. **라우팅 규칙 설정:**
   ```
   VPC1 → VPC2: 목적지 10.2.1.0/24
   VPC2 → VPC1: 목적지 10.1.1.0/24
   ```

### &#128906; VPC Peering 연결 테스트

```bash
# VPC1 (cewebvm111r)에서 VPC2 서버로 HTTP 연결 테스트
curl -I http://10.2.1.211/ --connect-timeout 5

# VPC2 (bbwebvm211r)에서 VPC1 서버로 HTTP 연결 테스트  
curl -I http://10.1.1.111/ --connect-timeout 5

# 연결 성공 시 HTTP 응답 헤더가 표시됩니다
# 실패 시 timeout 또는 connection refused 메시지 표시
```

## Cross VPC Load Balancer 구성 (수동 설정)

### &#128906; Load Balancer용 Public IP 예약

**Samsung Cloud Platform v2 콘솔에서:**
- 구분: Internet Gateway
- Load Balancer 전용 Public IP 할당

### &#128906; Cross VPC Load Balancer 생성

**Load Balancer 기본 설정:**
- Load Balancer명: ceweblb
- 서비스 구분: L7 (HTTP 기반)
- VPC: VPC1
- Service Subnet: Subnet11 (10.1.1.0/24)
- Service IP: 10.1.1.100
- Public NAT IP: 사용 (앞서 예약한 Public IP)
- Firewall 사용: 사용
- Firewall 로그 저장: 사용

### &#128906; Creative Energy 서버 그룹 생성

**ceweb LB 서버 그룹:**
- LB 서버 그룹명: ceweblbgrp
- VPC: VPC1
- Service Subnet: Subnet11
- 부하 분산: Round Robin
- 프로토콜: TCP
- LB 헬스 체크: HTTP_Default_Port80
- 연결된 자원: cewebvm111r (10.1.1.111)
- 가중치: 1

### &#128906; Big Boys 서버 그룹 생성 (Cross VPC)

**bbweb LB 서버 그룹:**
- LB 서버 그룹명: bbweblbgrp  
- VPC: VPC1 (Load Balancer와 동일)
- Service Subnet: Subnet11
- 부하 분산: Round Robin
- 프로토콜: TCP
- LB 헬스 체크: HTTP_Default_Port80
- **연결된 자원: 10.2.1.211** (Cross VPC - bbwebvm211r의 IP)
- 가중치: 1

### &#128906; Listener 구성

**Creative Energy Listener:**
- Listener명: celistener
- 프로토콜: HTTP
- 서비스 포트: 80
- 기본 서버 그룹: ceweblbgrp
- 세션 유지 시간: 120초
- 지속성: 소스 IP

**URL 기반 라우팅 설정 (L7 기능):**
- **기본 경로 (/)**: ceweblbgrp (Creative Energy)
- **특정 경로 (/artist/bbweb)**: bbweblbgrp (Big Boys)

## 통신 제어 규칙 추가

Cross VPC Load Balancing을 위한 추가 보안 규칙을 설정합니다.

### &#128906; Firewall 규칙 추가

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Manual Add|VPC1 IGW|Your Public IP|10.1.1.100(Service IP)|TCP 80|Allow|Inbound|클라이언트 → LB 연결|
|Manual Add|Load Balancer|Your Public IP|10.1.1.100(Service IP)|TCP 80|Allow|Outbound|클라이언트 → LB 연결|
|Manual Add|Load Balancer|LB Source NAT IP|10.1.1.111, 10.2.1.211|TCP 80|Allow|Inbound|LB → 멤버 연결 (Cross VPC)|
|Manual Add|Load Balancer|LB 헬스체크 IP|10.1.1.111, 10.2.1.211|TCP 80|Allow|Inbound|LB → 헬스체크 (Cross VPC)|

### &#128906; Security Group 규칙 추가

추가로 필요한 Security Group 규칙:

|Security Group|Direction|Target|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----|
|cewebSG|Inbound|LB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|cewebSG|Inbound|LB 헬스체크 IP|TCP 80|Healthcheck from Load Balancer|
|bbwebSG|Inbound|LB Source NAT IP|TCP 80|HTTP inbound from Load Balancer (Cross VPC)|
|bbwebSG|Inbound|LB 헬스체크 IP|TCP 80|Healthcheck from Load Balancer (Cross VPC)|

## 서비스 테스트 및 확인

### &#128906; Load Balancer 접속 테스트

**웹 애플리케이션 접속:**
- **Load Balancer를 통한 접속**: http://[LB-Public-IP]/ 
- **Creative Energy 페이지**: 기본 경로로 접근
- **Big Boys 페이지**: http://[LB-Public-IP]/artist/bbweb/ 으로 접근

### &#128906; Cross VPC 통신 확인

**1. 헬스체크 상태 확인**
- Samsung Cloud Platform v2 콘솔에서 Load Balancer 상태 확인
- 양쪽 VPC의 서버가 모두 Healthy 상태인지 확인

**2. 부하분산 동작 확인**
```bash
# bbwebvm211r(10.2.1.211)에서 테스트
cd /home/rocky/ceweb/artist/bbweb/
sudo vi index_lb.html

# "CREATIVE ENERGY" 또는 "BIG BOYS" 텍스트를 다른 내용으로 변경
# 브라우저에서 새로고침하여 변경사항 확인
```

**3. 실시간 로그 모니터링**
```bash
# 각 웹서버에서 접속 로그 확인
sudo tail -f /var/log/nginx/access.log
```

## 고급 활용 (선택사항)

### &#128906; SSL 인증서 적용

**Load Balancer에서 HTTPS 설정:**
1. SSL 인증서 업로드 (Samsung Cloud Platform v2 콘솔)
2. Listener를 HTTPS(443)로 변경
3. HTTP → HTTPS 리다이렉트 설정

### &#128906; 모니터링 및 알람 설정

**CloudWatch 연동:**
- Load Balancer 메트릭 수집
- 헬스체크 실패 시 알람 설정
- Cross VPC 트래픽 모니터링

## 자원 삭제

실습 완료 후 비용 절약을 위해 생성된 자원을 정리합니다.

### &#128906; 수동 삭제 순서 (콘솔에서 수행)

**Load Balancer 관련:**
1. Load Balancer Listener 삭제
2. Load Balancer 서버 그룹 삭제 (ceweblbgrp, bbweblbgrp)
3. Load Balancer 삭제 (ceweblb)
4. Load Balancer용 Public IP 삭제

**네트워킹:**
5. VPC Peering 삭제 (cepeering12)

### &#128906; PowerShell 자동 삭제 (권장)

```powershell
cd C:\Users\dion\.local\bin\scpv2\advance_networking\load_balancing\
terraform destroy --auto-approve
```

### &#128906; 삭제 확인

```bash
# terraform state 확인
terraform show

# 삭제 완료 후 state 파일 정리
rm -f terraform.tfstate*
rm -f tfplan  
rm -f master_config.json
```

## 학습 완료 및 다음 단계

**완료된 학습 목표:**
- ✅ Cross VPC Load Balancing 아키텍처 이해
- ✅ VPC Peering을 통한 네트워크 연결
- ✅ L7 Load Balancer의 고급 기능 (URL 기반 라우팅)
- ✅ 수동 설정을 통한 깊이 있는 네트워킹 학습

**다음 단계 학습:**
- 완전 자동화된 Multi-AZ Load Balancer 구성
- Auto Scaling과 연동된 동적 확장
- API Gateway와 Microservices 아키텍처
- Container 기반 Load Balancing (EKS/ECS)

## 트러블슈팅

### 일반적인 문제 해결

**1. VPC Peering 연결 실패**
```bash
# 라우팅 테이블 확인
# Security Group 규칙 재확인  
# Firewall 정책 점검
```

**2. Load Balancer 헬스체크 실패**
```bash
# 웹서버 상태 확인
sudo systemctl status nginx

# 포트 리스닝 확인
sudo netstat -tlnp | grep :80

# 방화벽 상태 확인
sudo firewall-cmd --list-all
```

**3. Cross VPC 통신 안됨**
```bash
# HTTP 연결 테스트 (ping은 ICMP 프로토콜로 SG에서 차단됨)
curl -I http://10.2.1.211/ --connect-timeout 5

# 실패 시 확인사항:
# - VPC Peering 승인 상태 확인
# - 라우팅 테이블에 올바른 경로 설정 확인  
# - Security Group에서 Cross VPC 통신 허용 확인
```