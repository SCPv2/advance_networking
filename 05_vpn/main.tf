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
resource "samsungcloudplatformv2_vpc_vpc" "vpcs" {
  for_each    = { for v in var.vpcs : v.name => v }
  name        = each.value.name
  cidr        = each.value.cidr
  description = lookup(each.value, "description", null)
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

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpcs]
}

########################################################
# Subnet 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "subnets" {
  for_each    = { for sb in var.subnets : sb.name => sb }
  name        = each.value.name
  cidr        = each.value.cidr
  type        = each.value.type
  description = each.value.description
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpcs[each.value.vpc_name].id

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

############################
# Public IP
############################
resource "samsungcloudplatformv2_vpc_publicip" "pip1" {
  type        = "IGW"
}

############################
# Security Group
############################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name        = var.security_group_bastion
  loggable    = false
}

resource "samsungcloudplatformv2_security_group_security_group" "nfsvm_sg" {
  name        = var.security_group_web
  loggable    = false
}

############################
# Ports
############################
resource "samsungcloudplatformv2_vpc_port" "bastion_port" {
  name            = var.port_names.bastion
  subnet_id       = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet,subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "nfsvm_port" {
  name            = var.port_names.nfsvm
  subnet_id       = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.nfsvm_sg,
    samsungcloudplatformv2_vpc_subnet,subnets
  ]
}

########################################################
# Virtual Server Standard Image ID 조회
########################################################
# Windows
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

# Rocky
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

locals {
  windows_ids = try(data.samsungcloudplatformv2_virtualserver_images.windows.ids, [])
  rocky_ids   = try(data.samsungcloudplatformv2_virtualserver_images.rocky.ids, [])

  windows_image_id_first = length(local.windows_ids) > 0 ? local.windows_ids[0] : ""
  rocky_image_id_first   = length(local.rocky_ids)   > 0 ? local.rocky_ids[0]   : ""
}

########################################################
# Virtual Server 자원 생성
########################################################

# Bastion Host (bastion)
resource "samsungcloudplatformv2_virtualserver_server" "vm1" {
  name           = var.vm_bastion.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"

  boot_volume = {
    size                  = var.boot_volume_bastion.size
    type                  = var.boot_volume_bastion.type
    delete_on_termination = var.boot_volume_bastion.delete_on_termination
  }

  image_id = local.windows_image_id_first

  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pip1.id,
      port_id      = samsungcloudplatformv2_vpc_port.bastion_port.id,
      subnet_id    = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
    }
  }

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.pip1
  ]
}

# VM for NFS (nfsvm)
resource "samsungcloudplatformv2_virtualserver_server" "vm2" {
  name           = var.vm_nfsvm.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"

  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }

  image_id = local.rocky_image_id_first

  networks = {
    interface_1 : {
      subnet_id : samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id,
      port_id = samsungcloudplatformv2_vpc_port.nfsvm_port.id
    }
  }

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.nfsvm_sg
  ]
}
