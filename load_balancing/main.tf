########################################################
# Provider : Samsung Cloud Platform v2
########################################################
terraform {
  required_providers {
    samsungcloudplatformv2 = {
      version = "1.0.3"
      source  = "SamsungSDSCloud/samsungcloudplatformv2"
    }
  }
  required_version = ">= 1.11"
}

provider "samsungcloudplatformv2" {
}

########################################################
# VPC 자원 생성 
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpc1" {
  name        = "VPC1"
  cidr        = "10.1.0.0/16"
  description = "Creative Energy VPC"
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_vpc_vpc" "vpc2" {
  name        = "VPC2"
  cidr        = "10.2.0.0/16"
  description = "Big Boys VPC"
  tags        = var.common_tags
}

########################################################
# Internet Gateway 생성, VPC 연결
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw1" {
  type              = "IGW"
  vpc_id            = samsungcloudplatformv2_vpc_vpc.vpc1.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpc1]
}

resource "samsungcloudplatformv2_vpc_internet_gateway" "igw2" {
  type              = "IGW"
  vpc_id            = samsungcloudplatformv2_vpc_vpc.vpc2.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpc2]
}

########################################################
# Subnet 생성 
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "subnet11" {
  name        = "Subnet11"
  type        = "GENERAL"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc1.id
  cidr        = "10.1.1.0/24"
  description = "Creative Energy Subnet"
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw1]
}

resource "samsungcloudplatformv2_vpc_subnet" "subnet21" {
  name        = "Subnet21"
  type        = "GENERAL"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc2.id
  cidr        = "10.2.1.0/24"
  description = "Big Boys Subnet"
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw2]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

########################################################
# Public IP 생성 (Bastion, CE Web, BB Web)
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "pip1" {
  type        = "IGW"
  description = "Public IP for Bastion VM"
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_vpc_publicip" "pip2" {
  type        = "IGW"
  description = "Public IP for Creative Energy Web VM"
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_vpc_publicip" "pip3" {
  type        = "IGW"
  description = "Public IP for Big Boys Web VM"
  tags        = var.common_tags
}

########################################################
# Security Groups
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name     = var.security_group_bastion
  loggable = false
  tags     = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "ceweb_sg" {
  name     = var.security_group_ceweb
  loggable = false
  tags     = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "bbweb_sg" {
  name     = var.security_group_bbweb
  loggable = false
  tags     = var.common_tags
}

########################################################
# IGW Firewall ID 참조
########################################################
locals {
  igw1_firewall_id = samsungcloudplatformv2_vpc_internet_gateway.igw1.internet_gateway.firewall_id
  igw2_firewall_id = samsungcloudplatformv2_vpc_internet_gateway.igw2.internet_gateway.firewall_id
}

########################################################
# VPC1 IGW Firewall 규칙
########################################################
# VPC1 IGW Outbound: VM → Internet (HTTP/HTTPS)
resource "samsungcloudplatformv2_firewall_firewall_rule" "vpc1_vm_http_out_fw" {
  firewall_id = local.igw1_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.bastion_ip, var.ceweb1_ip]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound from vm to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]
  }

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw1]
}

# VPC1 IGW Inbound: User PC → Bastion (RDP)
resource "samsungcloudplatformv2_firewall_firewall_rule" "vpc1_bastion_rdp_in_fw" {
  firewall_id = local.igw1_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.bastion_ip]
    description         = "RDP inbound to bastion"
    service = [
      { service_type = "TCP", service_value = "3389" }
    ]
  }

  depends_on = [samsungcloudplatformv2_firewall_firewall_rule.vpc1_vm_http_out_fw]
}

########################################################
# VPC2 IGW Firewall 규칙
########################################################
# VPC2 IGW Outbound: VM → Internet (HTTP/HTTPS)
resource "samsungcloudplatformv2_firewall_firewall_rule" "vpc2_vm_http_out_fw" {
  firewall_id = local.igw2_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = ["10.2.1.0/24"]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound from vm to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]
  }

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw2]
}

########################################################
# Security Group 규칙 - Bastion SG
########################################################
# Bastion SG Inbound: User PC → Bastion (RDP)
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_rdp_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 3389
  port_range_max    = 3389
  description       = "RDP inbound to bastion VM"
  remote_ip_prefix  = "${var.user_public_ip}/32"

  depends_on = [samsungcloudplatformv2_security_group_security_group.bastion_sg]
}

# Bastion SG Outbound: Bastion → Internet (HTTP)
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_rdp_in_sg]
}

# Bastion SG Outbound: Bastion → Internet (HTTPS)
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_http_out_sg]
}

########################################################
# Security Group 규칙 - CEWeb SG
########################################################
# CEWeb SG Outbound: CEWeb → Internet (HTTPS)
resource "samsungcloudplatformv2_security_group_security_group_rule" "ceweb_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_https_out_sg]
}

# CEWeb SG Outbound: CEWeb → Internet (HTTP)
resource "samsungcloudplatformv2_security_group_security_group_rule" "ceweb_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.ceweb_https_out_sg]
}

########################################################
# Security Group 규칙 - BBWeb SG
########################################################
# BBWeb SG Outbound: BBWeb → Internet (HTTP)
resource "samsungcloudplatformv2_security_group_security_group_rule" "bbweb_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bbweb_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.ceweb_http_out_sg]
}

# BBWeb SG Outbound: BBWeb → Internet (HTTPS)
resource "samsungcloudplatformv2_security_group_security_group_rule" "bbweb_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bbweb_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bbweb_http_out_sg]
}

########################################################
# Virtual Server Standard Image ID 조회
########################################################
# Windows 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "windows" {
  os_distro = var.image_windows_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_windows_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_windows_scp_os_version]
    use_regex = false
  }
}

# Rocky 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "rocky" {
  os_distro = var.image_rocky_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_rocky_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_rocky_scp_os_version]
    use_regex = false
  }
}

# 이미지 Local 변수 지정
locals {
  windows_ids = try(data.samsungcloudplatformv2_virtualserver_images.windows.ids, [])
  rocky_ids   = try(data.samsungcloudplatformv2_virtualserver_images.rocky.ids, [])

  windows_image_id_first = length(local.windows_ids) > 0 ? local.windows_ids[0] : ""
  rocky_image_id_first   = length(local.rocky_ids)   > 0 ? local.rocky_ids[0]   : ""
}

#######################################################
# Virtual Machine 생성 
########################################################
# Bastion VM (Windows)
resource "samsungcloudplatformv2_virtualserver_server" "bastion_vm" {
  name           = var.vm_bastion.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_windows.size
    type                  = var.boot_volume_windows.type
    delete_on_termination = var.boot_volume_windows.delete_on_termination
  }

  image_id = local.windows_image_id_first

  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pip1.id
      subnet_id    = samsungcloudplatformv2_vpc_subnet.subnet11.id
      fixed_ip     = var.bastion_ip
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.ceweb_vm,
    samsungcloudplatformv2_virtualserver_server.bbweb_vm,
    samsungcloudplatformv2_vpc_subnet.subnet11,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.pip1,
    samsungcloudplatformv2_security_group_security_group_rule.bbweb_https_out_sg
  ]
}

# Creative Energy Web VM (Rocky Linux)
resource "samsungcloudplatformv2_virtualserver_server" "ceweb_vm" {
  name           = var.vm_ceweb1.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }

  image_id = local.rocky_image_id_first

  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pip2.id
      subnet_id    = samsungcloudplatformv2_vpc_subnet.subnet11.id
      fixed_ip     = var.ceweb1_ip
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.ceweb_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet11,
    samsungcloudplatformv2_security_group_security_group.ceweb_sg,
    samsungcloudplatformv2_vpc_publicip.pip2
  ]
}

# Big Boys Web VM (Rocky Linux)
resource "samsungcloudplatformv2_virtualserver_server" "bbweb_vm" {
  name           = var.vm_bbweb1.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }

  image_id = local.rocky_image_id_first

  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pip3.id
      subnet_id    = samsungcloudplatformv2_vpc_subnet.subnet21.id
      fixed_ip     = var.bbweb1_ip
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.bbweb_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet21,
    samsungcloudplatformv2_security_group_security_group.bbweb_sg,
    samsungcloudplatformv2_vpc_publicip.pip3
  ]
}