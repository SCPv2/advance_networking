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
# Local Values for Resource Mapping
########################################################
locals {
  # Subnet mapping
  ceweb_subnet_name = "Subnet11"
  bbweb_subnet_name = "Subnet21"
  
  # Public IP mapping
  bastion_pip_name = "PIP1"
  ceweb_pip_name   = "PIP2"
  bbweb_pip_name   = "PIP3"
  
  # VPC names
  ceweb_vpc_name = "VPC1"
  bbweb_vpc_name = "VPC2"
}

########################################################
# VPC 자원 생성 (2개 VPC)
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpcs" {
  for_each    = { for v in var.vpcs : v.name => v }
  name        = each.value.name
  cidr        = each.value.cidr
  description = lookup(each.value, "description", null)

  tags = var.common_tags
}

########################################################
# Internet Gateway 생성, VPC 연결
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw" {
  for_each          = samsungcloudplatformv2_vpc_vpc.vpcs
  type              = "IGW"
  name              = "${each.value.name}_igw"
  vpc_id            = each.value.id
  firewall_enabled  = true
  firewall_loggable = true
  description       = "IGW for ${each.value.name}"

  tags = var.common_tags
}

########################################################
# Subnet 생성 (각 VPC당 1개씩)
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "subnets" {
  for_each = { for s in var.subnets : s.name => s }
  
  name        = each.value.name
  type        = each.value.type
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpcs[each.value.vpc_name].id
  cidr        = each.value.cidr
  description = each.value.description

  tags = var.common_tags
}

########################################################
# Public IP 생성 (3개: Bastion, CE Web, BB Web)
########################################################
resource "samsungcloudplatformv2_vpc_public_ip" "pips" {
  for_each = { for p in var.public_ips : p.name => p }
  
  name        = each.value.name
  description = each.value.description
  ip_type     = "IGW"

  tags = var.common_tags
}

########################################################
# Firewall Rules for Internet Gateway
########################################################
resource "samsungcloudplatformv2_vpc_firewall_rule" "igw_rules" {
  for_each = samsungcloudplatformv2_vpc_internet_gateway.igw

  firewall_id = each.value.firewall_id
  name        = "${each.key}_firewall_rules"
  description = "Firewall rules for ${each.key}"
  
  # Allow outbound HTTP/HTTPS from VMs to Internet
  outbound_rule {
    name        = "outbound_http_https"
    action      = "ALLOW"
    protocol    = "TCP"
    priority    = 1
    source      = [samsungcloudplatformv2_vpc_vpc.vpcs[each.key].cidr]
    destination = ["0.0.0.0/0"]
    port        = [80, 443]
    description = "Allow HTTP/HTTPS outbound from VMs to Internet"
  }
  
  # Allow RDP inbound to bastion (only for VPC1)
  dynamic "inbound_rule" {
    for_each = each.key == "VPC1" ? [1] : []
    content {
      name        = "inbound_rdp_bastion"
      action      = "ALLOW" 
      protocol    = "TCP"
      priority    = 2
      source      = [var.user_public_ip]
      destination = [var.bastion_ip]
      port        = [3389]
      description = "Allow RDP inbound to bastion from user PC"
    }
  }
  
  # Allow HTTP inbound to web servers
  dynamic "inbound_rule" {
    for_each = each.key == "VPC1" ? [var.ceweb1_ip] : each.key == "VPC2" ? [var.bbweb1_ip] : []
    content {
      name        = "inbound_http_web"
      action      = "ALLOW"
      protocol    = "TCP" 
      priority    = 3
      source      = [var.user_public_ip]
      destination = [inbound_rule.value]
      port        = [80]
      description = "Allow HTTP inbound to web server from user PC"
    }
  }

  tags = var.common_tags
}

########################################################
# Security Group for Bastion (VPC1)
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name        = var.security_group_bastion
  description = "Security group for bastion VM"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpcs["VPC1"].id
  
  tags = var.common_tags
}

resource "samsungcloudplatformv2_security_group_rule" "bastion_sg_rules" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  name              = "${var.security_group_bastion}_rules"
  description       = "Security group rules for bastion"
  
  # Allow RDP inbound from user PC
  inbound_rule {
    name            = "inbound_rdp_user"
    ip_protocol     = "TCP"
    from_port       = 3389
    to_port         = 3389
    source_address  = [var.user_public_ip]
    description     = "RDP inbound from user PC"
  }
  
  # Allow SSH outbound to CE web server
  outbound_rule {
    name                = "outbound_ssh_ceweb"
    ip_protocol         = "TCP"
    from_port           = 22
    to_port             = 22
    remote_group_id     = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
    description         = "SSH outbound to CE web server"
  }
  
  # Allow SSH outbound to BB web server (Cross VPC)
  outbound_rule {
    name                = "outbound_ssh_bbweb"
    ip_protocol         = "TCP"
    from_port           = 22
    to_port             = 22
    destination_address = [var.bbweb1_ip]
    description         = "SSH outbound to BB web server"
  }
  
  # Allow HTTP/HTTPS outbound to Internet
  outbound_rule {
    name                = "outbound_http_internet"
    ip_protocol         = "TCP"
    from_port           = 80
    to_port             = 80
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP outbound to Internet"
  }
  
  outbound_rule {
    name                = "outbound_https_internet"
    ip_protocol         = "TCP"
    from_port           = 443
    to_port             = 443
    destination_address = ["0.0.0.0/0"]
    description         = "HTTPS outbound to Internet"
  }
  
  tags = var.common_tags
}

########################################################
# Security Group for Creative Energy Web Server (VPC1)
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "ceweb_sg" {
  name        = var.security_group_ceweb
  description = "Security group for Creative Energy web VM"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpcs["VPC1"].id
  
  tags = var.common_tags
}

resource "samsungcloudplatformv2_security_group_rule" "ceweb_sg_rules" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
  name              = "${var.security_group_ceweb}_rules"
  description       = "Security group rules for Creative Energy web server"
  
  # Allow SSH inbound from bastion
  inbound_rule {
    name            = "inbound_ssh_bastion"
    ip_protocol     = "TCP"
    from_port       = 22
    to_port         = 22
    remote_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
    description     = "SSH inbound from bastion"
  }
  
  # Allow HTTP inbound from user PC
  inbound_rule {
    name            = "inbound_http_user"
    ip_protocol     = "TCP"
    from_port       = 80
    to_port         = 80
    source_address  = [var.user_public_ip]
    description     = "HTTP inbound from user PC"
  }
  
  # Allow HTTP inbound from Load Balancer (준비 목적)
  inbound_rule {
    name            = "inbound_http_lb_ready"
    ip_protocol     = "TCP"
    from_port       = 80
    to_port         = 80
    source_address  = ["10.0.0.0/8"]
    description     = "HTTP inbound from Load Balancer (for future setup)"
  }
  
  # Allow HTTP/HTTPS outbound to Internet
  outbound_rule {
    name                = "outbound_http_internet"
    ip_protocol         = "TCP"
    from_port           = 80
    to_port             = 80
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP outbound to Internet"
  }
  
  outbound_rule {
    name                = "outbound_https_internet"
    ip_protocol         = "TCP"
    from_port           = 443
    to_port             = 443
    destination_address = ["0.0.0.0/0"]
    description         = "HTTPS outbound to Internet"
  }
  
  tags = var.common_tags
}

########################################################
# Security Group for Big Boys Web Server (VPC2)
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bbweb_sg" {
  name        = var.security_group_bbweb
  description = "Security group for Big Boys web VM"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpcs["VPC2"].id
  
  tags = var.common_tags
}

resource "samsungcloudplatformv2_security_group_rule" "bbweb_sg_rules" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bbweb_sg.id
  name              = "${var.security_group_bbweb}_rules"
  description       = "Security group rules for Big Boys web server"
  
  # Allow SSH inbound from bastion (Cross VPC)
  inbound_rule {
    name            = "inbound_ssh_bastion_cross"
    ip_protocol     = "TCP"
    from_port       = 22
    to_port         = 22
    source_address  = [var.bastion_ip]
    description     = "SSH inbound from bastion (Cross VPC)"
  }
  
  # Allow HTTP inbound from user PC
  inbound_rule {
    name            = "inbound_http_user"
    ip_protocol     = "TCP"
    from_port       = 80
    to_port         = 80
    source_address  = [var.user_public_ip]
    description     = "HTTP inbound from user PC"
  }
  
  # Allow HTTP inbound from Load Balancer (준비 목적)
  inbound_rule {
    name            = "inbound_http_lb_ready"
    ip_protocol     = "TCP"
    from_port       = 80
    to_port         = 80
    source_address  = ["10.0.0.0/8"]
    description     = "HTTP inbound from Load Balancer (for future setup)"
  }
  
  # Allow HTTP/HTTPS outbound to Internet
  outbound_rule {
    name                = "outbound_http_internet"
    ip_protocol         = "TCP"
    from_port           = 80
    to_port             = 80
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP outbound to Internet"
  }
  
  outbound_rule {
    name                = "outbound_https_internet"
    ip_protocol         = "TCP"
    from_port           = 443
    to_port             = 443
    destination_address = ["0.0.0.0/0"]
    description         = "HTTPS outbound to Internet"
  }
  
  tags = var.common_tags
}

########################################################
# Port for VM IP Assignment
########################################################
resource "samsungcloudplatformv2_vpc_port" "bastion_port" {
  name              = "bastionPort"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
  private_ip        = var.bastion_ip
  security_group_ids = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]
  description       = "Port for bastion VM"

  tags = var.common_tags
}

resource "samsungcloudplatformv2_vpc_port" "ceweb_port" {
  name               = "cewebPort"
  subnet_id          = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
  private_ip         = var.ceweb1_ip
  security_group_ids = [samsungcloudplatformv2_security_group_security_group.ceweb_sg.id]
  description        = "Port for Creative Energy web VM"

  tags = var.common_tags
}

resource "samsungcloudplatformv2_vpc_port" "bbweb_port" {
  name               = "bbwebPort"
  subnet_id          = samsungcloudplatformv2_vpc_subnet.subnets[local.bbweb_subnet_name].id
  private_ip         = var.bbweb1_ip
  security_group_ids = [samsungcloudplatformv2_security_group_security_group.bbweb_sg.id]
  description        = "Port for Big Boys web VM"

  tags = var.common_tags
}

########################################################
# Virtual Server Standard Image
########################################################
data "samsungcloudplatformv2_standard_image" "windows_image" {
  service_group = "COMPUTE"
  service       = "Virtual Server"
  region        = "KOREA"
  os_distro     = var.image_windows_os_distro
  os_version    = var.image_windows_scp_os_version
}

data "samsungcloudplatformv2_standard_image" "rocky_image" {
  service_group = "COMPUTE"
  service       = "Virtual Server" 
  region        = "KOREA"
  os_distro     = var.image_rocky_os_distro
  os_version    = var.image_rocky_scp_os_version
}

########################################################
# Bastion VM (Windows - VPC1)
########################################################
resource "samsungcloudplatformv2_virtualserver_server" "bastion_vm" {
  name          = var.vm_bastion.name
  description   = var.vm_bastion.description
  server_type   = var.server_type_id
  
  # Boot Volume
  initial_script {
    storage_name = "${var.vm_bastion.name}_storage"
    storage_size = var.boot_volume_windows.size
    storage_type = var.boot_volume_windows.type
    image_id     = data.samsungcloudplatformv2_standard_image.windows_image.id
  }
  
  # Network
  vpc_id        = samsungcloudplatformv2_vpc_vpc.vpcs[local.ceweb_vpc_name].id
  subnet_id     = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
  use_hyper_threading = false
  port_id       = samsungcloudplatformv2_vpc_port.bastion_port.id
  public_ip_id  = samsungcloudplatformv2_vpc_public_ip.pips[local.bastion_pip_name].id
  
  # SSH Key
  keypair_name  = var.keypair_name
  
  # Storage Settings
  delete_on_termination = var.boot_volume_windows.delete_on_termination
  
  tags = var.common_tags
}

########################################################
# Creative Energy Web VM (Rocky Linux - VPC1)
########################################################
resource "samsungcloudplatformv2_virtualserver_server" "ceweb_vm" {
  name          = var.vm_ceweb1.name
  description   = var.vm_ceweb1.description
  server_type   = var.server_type_id
  
  # Boot Volume
  initial_script {
    storage_name = "${var.vm_ceweb1.name}_storage"
    storage_size = var.boot_volume_rocky.size
    storage_type = var.boot_volume_rocky.type
    image_id     = data.samsungcloudplatformv2_standard_image.rocky_image.id
  }
  
  # Network
  vpc_id        = samsungcloudplatformv2_vpc_vpc.vpcs[local.ceweb_vpc_name].id
  subnet_id     = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
  use_hyper_threading = false
  port_id       = samsungcloudplatformv2_vpc_port.ceweb_port.id
  public_ip_id  = samsungcloudplatformv2_vpc_public_ip.pips[local.ceweb_pip_name].id
  
  # SSH Key
  keypair_name  = var.keypair_name
  
  # User Data Script
  user_data = base64encode(file("${path.module}/userdata_ceweb.sh"))
  
  # Storage Settings
  delete_on_termination = var.boot_volume_rocky.delete_on_termination
  
  tags = var.common_tags
  
  depends_on = [samsungcloudplatformv2_virtualserver_server.bastion_vm]
}

########################################################
# Big Boys Web VM (Rocky Linux - VPC2)
########################################################
resource "samsungcloudplatformv2_virtualserver_server" "bbweb_vm" {
  name          = var.vm_bbweb1.name
  description   = var.vm_bbweb1.description
  server_type   = var.server_type_id
  
  # Boot Volume
  initial_script {
    storage_name = "${var.vm_bbweb1.name}_storage"
    storage_size = var.boot_volume_rocky.size
    storage_type = var.boot_volume_rocky.type
    image_id     = data.samsungcloudplatformv2_standard_image.rocky_image.id
  }
  
  # Network
  vpc_id        = samsungcloudplatformv2_vpc_vpc.vpcs[local.bbweb_vpc_name].id
  subnet_id     = samsungcloudplatformv2_vpc_subnet.subnets[local.bbweb_subnet_name].id
  use_hyper_threading = false
  port_id       = samsungcloudplatformv2_vpc_port.bbweb_port.id
  public_ip_id  = samsungcloudplatformv2_vpc_public_ip.pips[local.bbweb_pip_name].id
  
  # SSH Key
  keypair_name  = var.keypair_name
  
  # User Data Script
  user_data = base64encode(file("${path.module}/userdata_bbweb.sh"))
  
  # Storage Settings
  delete_on_termination = var.boot_volume_rocky.delete_on_termination
  
  tags = var.common_tags
  
  depends_on = [samsungcloudplatformv2_virtualserver_server.bastion_vm]
}