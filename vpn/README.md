# IPsec VPN 구현

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## Samsung Cloud Platform 실습 환경 배포

**&#128906; 콘솔에서 Public IP 생성**

```bash
구분 : Internet Gateway
```

**&#128906; Samsung Cloud Platform 변수 입력 (\scp_deployment\variables.tf)**

```hcl
variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"

  default     = "x.x.x.x"                             🠈 수강자 PC의 Public IP 주소 입력

}
```

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
cd C:\scpv2advance\advance_networking\vpn\scp_deployment
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## AWS 실습 환경 배포

**&#128906; AWS 변수 입력 (\aws_deployment\main.tf)**

```hcl
provider "aws" {
  access_key = "put_your_aws_access_key"                🠈 AWS 사용자 인증키
  secret_key = "put_your_aws_secret_key"                🠈 AWS 사용자 인증키
  #token    = "unmask_and_put_your_token_if_neccessary" 🠈 토큰이 필요할 경우 마스크를 해제하고 값 입력
  region = "define_the_region_you_want_to_work_at"      🠈 자원을 배포할 Region 입력
}
 
resource "aws_customer_gateway" "cgw" {
  bgp_asn    = 65000
  ip_address = "x.x.x.x"                                🠈 여기에 앞서 생성한 SCP Public IP 주소 입력
  type       = "ipsec.1"
  tags       = { Name = "ceVPC-customer-gateway" }
}
```

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
cd C:\scpv2advance\advance_networking\vpn\aws_deployment
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## 환경 검토

**&#128906; Samsung Cloud Platform의 환경 검토**

- Architectuer Diagram
- VPC CIDR
- Subnet CIDR
- Virtual Server OS, Public IP, Private IP
- Firewall 규칙
- Security Group 규칙

**&#128906; AWS의 환경 검토**

- VPC CIDR
- Subnet CIDR
- Amazon EFS 마운트 정보
- EC2 instance Private IP
- Subnet Route Table
- Sercurity Group 규칙

**&#128906; 배포된 AWS site-to-site VPN 구성 설정 확인**

- 공급업체: Fortigate
- IKE버전: ikev1

## Samsung Cloud Platform VPN 구성

### VPN Gateway 생성

- VPN Gateway명                  : cevpn
- 연결 VPC                       : VPC1
- Public IP                     : 앞에서 생성한 Public IP 지정

### VPN Tunnel 생성

**서비스 정보**  

- VPN Tunnel명                  : ceawsvpntunnel
- VPN Gateway명                 : cevpn
- Peer VPN GW IP                : AWS 구성 정보 참고
- Remote Subnet(CIDR)           : 192.168.200.0/24
- Pre-shared Key                : AWS 구성 정보 참고  

**IKE 설정**  

- IKE Version                   : AWS 구성 정보 참고(기본: IKE v1)
- Encryption Algorithm          : AWS 구성 정보 참고(기본: aes128)
- Digest Algorithm              : AWS 구성 정보 참고(기본: sha1)
- Diffie-Hellman                : AWS 구성 정보 참고(기본: 2)
- SA LifeTime                   : AWS 구성 정보 참고(기본: 28800)

**IPSEC 설정**  

- IKE Version                   : AWS 구성 정보 참고(기본: IKE v1)
- Encryption Algorithm          : AWS 구성 정보 참고(기본: aes128)
- Perfect Forward Secrecy(PFS)  : AWS 구성 정보 참고(기본: 사용)
- Diffie-Hellman                : AWS 구성 정보 참고(기본: 2)
- SA LifeTime                   : AWS 구성 정보 참고(기본: 3600)
- DPD Probe Interval            : AWS 구성 정보 참고(기본: 30)

### 통신 제어 규칙 검토 및 새규칙 추가

### Firewall

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|IGW|10.1.1.110, 10.1.1.111|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vms to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|User Add|IGW|10.1.1.110|192.168.200.0/24|TCP 22|Allow|Outbound|SSH outbound to ec2 instance|
|User Add|IGW|10.1.1.111|192.168.200.0/24|TCP 2049|Allow|Outbound|NFS outbound to Amazon EFS|

### Security Group

|Deployment|Security Group|Direction|Target Address   Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terrafom|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terrafom|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|bastionSG|Outbound|nfsvmSG|TCP 22|SSH outbound to nfs vm |
|User Add|bastionSG|Outbound|192.168.200.0/24|TCP 22|SSH outbound to ec2 instance |
|||||||
|Terrafom|nfsvmSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|nfsvmSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|nfsvmSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|User Add|nfsvmSG|Outbound|192.168.200.0/24|TCP 2049|NFS connection outbound to Amazon EFS|

## VM 연결 및 NFS 마운트

### Bastion Server 접속

- 로컬 PC에서 Bastion Host로 다음 파일을 복사

```bash
C:\scpv2advance\mykey.ppk 
C:\scpv2advance\advance_networking\vpn\aws_deployment\awsmykey.pem 
C:\scpv2advance\advance_networking\vpn\scp_deployment\install_putty.ps1
```

- Bastion Host(10.1.1.110)에서 NFSVM(10.1.1.111)에 SSH(22) 접속
- Bastion Host(10.1.1.110)에서 ec2(192.168.200.X)에 SSH(22) 접속
- Amazon EFS Mount 정보 확인

- EC2(192.168.200.X)에서 다음 명령 실행

```bash
mkdir efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 192.168.200.x:/ efs   # 실제 마운트 정보는 AWS 콘솔에서 확인
df -h             # 마운트 확인
cd efs
sudo touch welcome!
```

- vm111r(10.1.1.111)에서 다음 명령 실행

```bash
mkdir efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 192.168.200.x:/ efs   # 실제 마운트 정보는 AWS 콘솔에서 확인
df -h             # 마운트 확인
cd efs
ls
sudo touch Thans_for_warm_welcome!
```
