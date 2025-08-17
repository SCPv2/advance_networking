terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  access_key = "youneedputaccesskeyhere"
  secret_key = "youneedputsecretkeyhere"
  # token    = " "
  region     = " "
}


# 1. 키페어 생성
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "awsmykey"
  public_key = tls_private_key.deployer.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.deployer.private_key_pem
  filename = "awsmykey.pem"
}

# 2. ceVPC 생성 (192.168.200.0/24)
resource "aws_vpc" "ce_vpc" {
  cidr_block = "192.168.200.0/24"
  tags       = { Name = "ceVPC" }
}

# 3. ceSBN 서브넷 생성 (192.168.200.0/28)
data "aws_availability_zones" "available" {}

resource "aws_subnet" "ce_sbn" {
  vpc_id            = aws_vpc.ce_vpc.id
  cidr_block        = "192.168.200.0/28"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "ceSBN" }
}

# 4. ceSG 보안 그룹 생성 (TCP All from 10.0.0.0/16 and 192.168.200.0/24)
resource "aws_security_group" "ce_sg" {
  name        = "ceSG"
  description = "Allow inbound TCP all from 10.0.0.0/16 and 192.168.200.0/24"
  vpc_id      = aws_vpc.ce_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "192.168.200.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ceSG" }
}

# 5. VPN Gateway 생성 및 ceVPC에 연결
resource "aws_vpn_gateway" "vgw" {
  vpc_id = aws_vpc.ce_vpc.id
  tags   = { Name = "ceVPC-vpn-gateway" }
}

# 6. 고객 게이트웨이 생성 (IP: 123.41.33.171)
resource "aws_customer_gateway" "cgw" {
  bgp_asn    = 65000
  ip_address = "123.41.33.171"
  type       = "ipsec.1"
  tags       = { Name = "ceVPC-customer-gateway" }
}

# 7. Site-to-Site VPN 연결 (정적 라우트 사용)
resource "aws_vpn_connection" "site_to_site" {
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.cgw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = { Name = "ceVPC-site-to-site-vpn" }
}

# 8. 정적 라우트 (원격 네트워크 10.0.0.0/16)
resource "aws_vpn_connection_route" "site_to_site_route" {
  vpn_connection_id      = aws_vpn_connection.site_to_site.id
  destination_cidr_block = "10.0.0.0/16"
}

# 9. EFS 파일 시스템 생성 (이 VPC 대상, 이름: ce-efs)
resource "aws_efs_file_system" "ce_efs" {
  creation_token = "ce-efs"
  tags           = { Name = "ce-efs" }
}

# 10. EFS Mount Target 생성 (ceSBN, ceSG 적용)
resource "aws_efs_mount_target" "ce_efs_mt" {
  file_system_id  = aws_efs_file_system.ce_efs.id
  subnet_id       = aws_subnet.ce_sbn.id
  security_groups = [aws_security_group.ce_sg.id]
}

# 11. Private key output for download
output "private_key_pem" {
  description = "Private key content. Save to awsmykey.pem"
  value       = tls_private_key.deployer.private_key_pem
  sensitive   = true
}

# 12. Amazon Linux EC2 인스턴스 생성
#    서브넷 및 키페어 연결
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "ce_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.ce_sbn.id
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ce_sg.id]

  tags = { Name = "ceEC2" }
}

# 13. 전용 라우팅 테이블 생성 및 규칙 추가
resource "aws_route_table" "ce_sbn_rt" {
  vpc_id = aws_vpc.ce_vpc.id
  tags   = { Name = "ceSBNrt" }
}

resource "aws_route" "ce_sbn_to_vgw" {
  route_table_id         = aws_route_table.ce_sbn_rt.id
  destination_cidr_block = "10.0.0.0/16"
  gateway_id             = aws_vpn_gateway.vgw.id
}

# 14. 서브넷에 라우팅 테이블 연결
resource "aws_route_table_association" "ce_sbn_assoc" {
  subnet_id      = aws_subnet.ce_sbn.id
  route_table_id = aws_route_table.ce_sbn_rt.id
}

