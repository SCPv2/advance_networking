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
  vpc_id            = each.value.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpcs]
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

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

########################################################
# Public IP 생성 (3개: Bastion, CE Web, BB Web)
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "pips" {
  for_each = { for p in var.public_ips : p.name => p }
  
  type        = "IGW"
  description = each.value.description

  tags = var.common_tags
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
# VPC Port 생성
########################################################
resource "samsungcloudplatformv2_vpc_port" "bastion_port" {
  name      = "bastion_port"
  subnet_id = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "ceweb_port" {
  name      = "ceweb_port"
  subnet_id = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.ceweb_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "bbweb_port" {
  name      = "bbweb_port"
  subnet_id = samsungcloudplatformv2_vpc_subnet.subnets[local.bbweb_subnet_name].id

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bbweb_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

#######################################################
# Virtual Machine 생성 (예시 - 필요시 추가)
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
  
  image_id = var.windows_image_id
  
  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pips[local.bastion_pip_name].id
      port_id      = samsungcloudplatformv2_vpc_port.bastion_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]
  
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.pips,
    samsungcloudplatformv2_vpc_port.bastion_port
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
  
  image_id = var.rocky_image_id
  
  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pips[local.ceweb_pip_name].id
      port_id      = samsungcloudplatformv2_vpc_port.ceweb_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.ceweb_sg.id]
  user_data       = base64encode(file("${path.module}/userdata_ceweb.sh"))
  
  depends_on = [
    samsungcloudplatformv2_virtualserver_server.bastion_vm,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.ceweb_sg,
    samsungcloudplatformv2_vpc_publicip.pips,
    samsungcloudplatformv2_vpc_port.ceweb_port
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
  
  image_id = var.rocky_image_id
  
  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pips[local.bbweb_pip_name].id
      port_id      = samsungcloudplatformv2_vpc_port.bbweb_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.bbweb_sg.id]
  user_data       = base64encode(file("${path.module}/userdata_bbweb.sh"))
  
  depends_on = [
    samsungcloudplatformv2_virtualserver_server.bastion_vm,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.bbweb_sg,
    samsungcloudplatformv2_vpc_publicip.pips,
    samsungcloudplatformv2_vpc_port.bbweb_port
  ]
}