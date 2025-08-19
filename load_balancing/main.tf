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

########################################################
# Public IP
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "publicips" {
  for_each    = { for pip in var.public_ips : pip.name => pip }
  type        = "IGW"
  description = each.value.description

 depends_on = [samsungcloudplatformv2_vpc_subnet.subnets] 
}

########################################################
# Security Group
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name        = var.security_group_bastion
  loggable    = false
}

resource "samsungcloudplatformv2_security_group_security_group" "ceweb_sg" {
  name        = var.security_group_ceweb
  loggable    = false
}

resource "samsungcloudplatformv2_security_group_security_group" "bbweb_sg" {
  name        = var.security_group_bbweb
  loggable    = false
}

########################################################
# 기본 통신 규칙 (Firewall)
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "igw_fws" {
  for_each = samsungcloudplatformv2_vpc_internet_gateway.igw
  name     = "FW_IGW_${each.key}"

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "vm_web_out_fw" {
  for_each = { for k, v in data.samsungcloudplatformv2_firewall_firewalls.igw_fws : k => v.ids[0] }

  firewall_id = each.value
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.bastion_ip, var.ceweb1_ip, var.bbweb1_ip]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]
  }

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "bastion_rdp_in_fw" {
  for_each = { for k, v in data.samsungcloudplatformv2_firewall_firewalls.igw_fws : k => v if k == local.ceweb_vpc_name }

  firewall_id = each.value.ids[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = ["${var.user_public_ip}/32"]
    destination_address = ["${var.bastion_ip}/32"]
    description         = "RDP inbound to bastion"
    service = [
      { service_type = "TCP", service_value = "3389" }
    ]
  }

  depends_on = [samsungcloudplatformv2_firewall_firewall_rule.vm_web_out_fw]
}

########################################################
# 기본 통신 규칙 (Security Group) - 순차적 종속성 적용
########################################################
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_RDP_in_sg" {
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

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_RDP_in_sg]
}

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

resource "samsungcloudplatformv2_security_group_security_group_rule" "ceweb_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "ceweb_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.ceweb_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bbweb_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bbweb_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.ceweb_https_out_sg]
}

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
# Subnet에 NAT Gateway 연결 - 하드코딩 제거
########################################################

resource "samsungcloudplatformv2_vpc_nat_gateway" "ceweb_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips[local.ceweb_pip_name].id
    description = "NAT for ceweb"

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "bbweb_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets[local.bbweb_subnet_name].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips[local.bbweb_pip_name].id
    description = "NAT for bbweb"

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

########################################################
# Ports - 하드코딩 제거
########################################################
resource "samsungcloudplatformv2_vpc_port" "bastion_port" {
  name              = "bastionport"
  description       = "bastion port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
  fixed_ip_address  = var.bastion_ip

  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "ceweb1_port" {
  name              = "ceweb1port"
  description       = "ceweb1 port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets[local.ceweb_subnet_name].id
  fixed_ip_address  = var.ceweb1_ip

  security_groups = [samsungcloudplatformv2_security_group_security_group.ceweb_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.ceweb_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "bbweb1_port" {
  name              = "bbweb1port"
  description       = "bbweb1 port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets[local.bbweb_subnet_name].id
  fixed_ip_address  = var.bbweb1_ip

  security_groups = [samsungcloudplatformv2_security_group_security_group.bbweb_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bbweb_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
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

########################################################
# Virtual Server 자원 생성 - 하드코딩 제거
########################################################

# bastion VM
resource "samsungcloudplatformv2_virtualserver_server" "vm1" {
  name           = var.vm_bastion.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"

  boot_volume = {
    size                  = var.boot_volume_windows.size
    type                  = var.boot_volume_windows.type
    delete_on_termination = var.boot_volume_windows.delete_on_termination
  }

  image_id = local.windows_image_id_first

  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.publicips[local.bastion_pip_name].id,
      port_id      = samsungcloudplatformv2_vpc_port.bastion_port.id
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.publicips,
    samsungcloudplatformv2_vpc_port.bastion_port
  ]
}

# ceweb1 VM
resource "samsungcloudplatformv2_virtualserver_server" "vm2" {
  name           = var.vm_ceweb1.name
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
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.ceweb1_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.ceweb_sg.id] 

  user_data = base64encode(file("${path.module}/userdata_ceweb.sh"))

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.ceweb_sg,
    samsungcloudplatformv2_vpc_port.ceweb1_port
  ]
}

# bbweb1 VM
resource "samsungcloudplatformv2_virtualserver_server" "vm4" {
  name           = var.vm_bbweb1.name
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
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.bbweb1_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.bbweb_sg.id] 

  user_data = base64encode(file("${path.module}/userdata_bbweb.sh"))

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.bbweb_sg,
    samsungcloudplatformv2_vpc_port.bbweb1_port
  ]
}