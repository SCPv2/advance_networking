# VPC 네트워크 설계 및 구현

## VPC 

**&#128906; Samsung Cloud Platform**

- VPC명 : `VPC1`
- IP대역 : `10.1.0.0/16`

**&#128906; 타 클라우드**

- 이름 태그 : VPC1
- IPv4 CIDR 블록 : IPv4 CIDR 수동입력
- IPv4 CIDR : `10.1.0.0/16`
- IPv6 CIDR 블록 : IPv6 CIDR 블록 없음

## Subnet

**&#128906; Samsung Cloud Platform**

(Subnet11)
- Subnet 유형 : General
- VPC : VPC1
- Subnet명 : `Subnet11`
- IP대역 : `10.1.1.0/24`
    
(Subnet12)  
- Subnet 유형 : General
- VPC : VPC1
- Subnet명 : `Subnet12`
- IP대역 : `10.1.2.0/24`
  
**&#128906; 타 클라우드**

(Subnet11)

- VPC ID : VPC1
- Subnet 이름 : `Subnet11`
- 가용 영역 : a
- IP대역 : `10.1.1.0/24`
    
(Subnet12)  

- VPC ID : VPC1
- Subnet 이름 : `Subnet12`
- 가용 영역 : a
- IP대역 : `10.1.2.0/24`

## Internet Gateway

**&#128906; Samsung Cloud Platform**

- VPC : VPC1
- 구분 : Internet Gateway
- Firewall : 사용
- Firewall 로그 저장 여부 : 사용하지 않음
  
**&#128906; 타 클라우드**

- VPC : VPC1에 연결

## Network Access Control

**&#128906; Samsung Cloud Platform**

- Firewall
  - 출발지 주소 : 수강자 PC Public IP 주소
  - 목적지 주소 : `10.1.1.0/24`
  - 유형 : 목적지 포트/Type 선택
     - 프로토콜 : TCP
     - TCP 목적지 포트 : RDP(3389)
  - 동작 : Allow
  - 방향 : Inbound

-Security Group(SG1)
  - Security Group명 : `SG1`
  - 로그 저장 여부 : 사용하지 않음
      - (규칙1)
      - Inbound 규칙
      - 유형 : RDP(3389)
      - 원격 : CIDR : 수강자 PC Public IP
      - (규칙2)
      - Outbound 규칙
      - 유형 : SSH(22)
      - 원격 : Security Group : SG2
    
-Security Group(SG2)
  - Security Group명 : `SG1`
  - 로그 저장 여부 : 사용하지 않음
      - (규칙1)
      - Inbound 규칙
      - 유형 : SSH(22)
      - 원격 : Security Group : SG1
  
## Virtual Machine

**&#128906; Samsung Cloud Platform**

(vm110w)
- Image 및 버전 선택 : Windows
- 서버명 : `vm110w`
- VPC : VPC1
- 일반 Subnet : Subnet11
- Pubic NAT : 사용
- Security Group : SG1
- Keypair : mykey

(vm111r)
- Image 및 버전 선택 : Rocky
- 서버명 : `vm111r`
- VPC : VPC1
- 일반 Subnet : Subnet12
- Security Group : SG2
- Keypair : mykey
  
**&#128906; 타 클라우드**

(vm110w)
- Image 및 버전 선택 : Windows
- 서버명 : `vm110w`
- VPC : VPC1
- Subnet : Subnet11
- Pubic IP 자동 할당 : 활성화
- 방화벽(보안 그룹) : 보안그룹 생성
- 보안그룹 이름 : SG1
  - RDP(3389), Inbound , 내PC IP
- Keypair : mykey

(vm111r)
- Image 및 버전 선택 : Amazon Linux
- 서버명 : `vm111r`
- VPC : VPC1
- Subnet : Subnet12
- Pubic IP 자동 할당 : 비활성화
- 방화벽(보안 그룹) : 보안그룹 생성
- 보안그룹 이름 : SG2
  - SSH(22), Inbound , SG1
- Keypair : mykey






