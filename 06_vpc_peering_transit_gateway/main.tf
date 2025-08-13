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
resource "samsungcloudplatformv2_security_group_security_group" "primary_sg" {
  name        = var.security_group_primary
  loggable    = false
}

resource "samsungcloudplatformv2_security_group_security_group" "secondary_sg" {
  name        = var.security_group_secondary
  loggable    = false
}

resource "samsungcloudplatformv2_security_group_security_group" "tertiary_sg" {
  name        = var.security_group_tertiary
  loggable    = false
}

########################################################
# 기본 통신 규칙 (Firewall)
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "igw_fws" {
  name     = "FW_IGW_VPC1"

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "vm_web_out_fw" {
  firewall_id = data.samsungcloudplatformv2_firewall_firewalls.igw_fws.ids[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.primary_ip, var.secondary_ip, var.tertiary_ip]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]

    depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
  }
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "primary_rdp_in_fw" {
  firewall_id = data.samsungcloudplatformv2_firewall_firewalls.igw_fws.ids[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.primary_ip]
    description         = "RDP inbound to primary"
    service = [
      { service_type = "TCP", service_value = "3389" }
    ]

    depends_on  = [samsungcloudplatformv2_firewall_firewall_rule.vm_web_out_fw]
  }
}

########################################################
# 기본 통신 규칙 (Security Group)
########################################################
resource "samsungcloudplatformv2_security_group_security_group_rule" "primary_RDP_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.primary_sg.id
  protocol          = "tcp"
  port_range_min    = 3389
  port_range_max    = 3389
  description       = "RDP inbound to Primary VM"
  remote_ip_prefix  = var.user_public_ip

  depends_on  = [samsungcloudplatformv2_security_group_security_group.primary_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "primary_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.primary_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.primary_RDP_in_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "primary_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.primary_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.primary_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "secondary_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.secondary_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.primary_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "secondary_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.secondary_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.secondary_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "tertiary_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.tertiary_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.secondary_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "tertiary_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.tertiary_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.tertiary_http_out_sg]
}

########################################################
# Subnet에 NAT Gateway 연결
########################################################

resource "samsungcloudplatformv2_vpc_nat_gateway" "secondary_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets["Subnet21"].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP2"].id
    description = "NAT for Secondary"

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.primary_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "tertiary_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets["Subnet31"].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP3"].id
    description = "NAT for Tertiary"

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.primary_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

########################################################
# Ports
########################################################
resource "samsungcloudplatformv2_vpc_port" "primary_port" {
  name              = "primaryport"
  description       = "primary port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
  fixed_ip_address  = var.primary_ip

  security_groups = [samsungcloudplatformv2_security_group_security_group.primary_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.primary_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "secondary_port" {
  name              = "secondaryport"
  description       = "secondary port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet21"].id
  fixed_ip_address  = var.secondary_ip

  security_groups = [samsungcloudplatformv2_security_group_security_group.secondary_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.secondary_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "tertiary_port" {
  name              = "tertiaryport"
  description       = "tertiary port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet31"].id
  fixed_ip_address  = var.tertiary_ip

  security_groups = [samsungcloudplatformv2_security_group_security_group.tertiary_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.tertiary_sg,
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
# Virtual Server 자원 생성
########################################################

# Primary VM
resource "samsungcloudplatformv2_virtualserver_server" "vm1" {
  name           = var.vm_primary.name
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
      public_ip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP1"].id,
      port_id      = samsungcloudplatformv2_vpc_port.primary_port.id
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.primary_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.primary_sg,
    samsungcloudplatformv2_vpc_publicip.publicips,
    samsungcloudplatformv2_vpc_port.primary_port
  ]
}

# Secondary VM
resource "samsungcloudplatformv2_virtualserver_server" "vm2" {
  name           = var.vm_secondary.name
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
      port_id = samsungcloudplatformv2_vpc_port.secondary_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.secondary_sg.id] 

  user_data = base64encode(file("${path.module}/userdata_secondary.sh"))

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.secondary_sg,
    samsungcloudplatformv2_vpc_port.secondary_port
  ]
}

# Tertiary VM
resource "samsungcloudplatformv2_virtualserver_server" "vm3" {
  name           = var.vm_tertiary.name
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
      port_id = samsungcloudplatformv2_vpc_port.tertiary_port.id
    }
  }
  
  security_groups = [samsungcloudplatformv2_security_group_security_group.tertiary_sg.id] 

  user_data = base64encode(file("${path.module}/userdata_tertiary.sh"))

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.secondary_sg,
    samsungcloudplatformv2_vpc_port.secondary_port
  ]
}
