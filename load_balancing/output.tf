########################################################
# Cross VPC Load Balancing 배포 정보
########################################################

output "deployment_info" {
  value = {
    project_name = "Cross VPC Load Balancing"
    architecture = "Multi-VPC Web Servers"
    deployment_time = timestamp()
    terraform_version = ">=1.11"
    provider_version = "1.0.3"
  }
  description = "Basic deployment information"
}

########################################################
# VPC 정보
########################################################

output "vpc_info" {
  value = {
    vpc1 = {
      name = samsungcloudplatformv2_vpc_vpc.vpcs["VPC1"].name
      id   = samsungcloudplatformv2_vpc_vpc.vpcs["VPC1"].id
      cidr = samsungcloudplatformv2_vpc_vpc.vpcs["VPC1"].cidr
      description = samsungcloudplatformv2_vpc_vpc.vpcs["VPC1"].description
    }
    vpc2 = {
      name = samsungcloudplatformv2_vpc_vpc.vpcs["VPC2"].name
      id   = samsungcloudplatformv2_vpc_vpc.vpcs["VPC2"].id
      cidr = samsungcloudplatformv2_vpc_vpc.vpcs["VPC2"].cidr
      description = samsungcloudplatformv2_vpc_vpc.vpcs["VPC2"].description
    }
  }
  description = "VPC information for cross VPC load balancing"
}

########################################################
# 서버 정보
########################################################

output "server_info" {
  value = {
    bastion = {
      name       = samsungcloudplatformv2_virtualserver_server.bastion_vm.name
      id         = samsungcloudplatformv2_virtualserver_server.bastion_vm.id
      private_ip = var.bastion_ip
      public_ip  = samsungcloudplatformv2_vpc_publicip.pips["PIP1"].id
      vpc        = "VPC1"
      os         = "Windows Server 2022"
    }
    ceweb_server = {
      name       = samsungcloudplatformv2_virtualserver_server.ceweb_vm.name
      id         = samsungcloudplatformv2_virtualserver_server.ceweb_vm.id
      private_ip = var.ceweb1_ip
      public_ip  = samsungcloudplatformv2_vpc_publicip.pips["PIP2"].id
      vpc        = "VPC1"
      os         = "Rocky Linux 9.4"
      service    = "Creative Energy Web"
    }
    bbweb_server = {
      name       = samsungcloudplatformv2_virtualserver_server.bbweb_vm.name
      id         = samsungcloudplatformv2_virtualserver_server.bbweb_vm.id
      private_ip = var.bbweb1_ip
      public_ip  = samsungcloudplatformv2_vpc_publicip.pips["PIP3"].id
      vpc        = "VPC2"
      os         = "Rocky Linux 9.4"
      service    = "Big Boys Web"
    }
  }
  description = "Server information for cross VPC load balancing"
}

########################################################
# 네트워크 구성 정보
########################################################

output "network_config" {
  value = {
    subnets = {
      vpc1_subnet = {
        name = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].name
        id   = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
        cidr = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].cidr
        vpc  = "VPC1"
      }
      vpc2_subnet = {
        name = samsungcloudplatformv2_vpc_subnet.subnets["Subnet21"].name
        id   = samsungcloudplatformv2_vpc_subnet.subnets["Subnet21"].id
        cidr = samsungcloudplatformv2_vpc_subnet.subnets["Subnet21"].cidr
        vpc  = "VPC2"
      }
    }
    internet_gateways = {
      vpc1_igw = {
        id = samsungcloudplatformv2_vpc_internet_gateway.igw["VPC1"].id
      }
      vpc2_igw = {
        id = samsungcloudplatformv2_vpc_internet_gateway.igw["VPC2"].id
      }
    }
  }
  description = "Network configuration for cross VPC setup"
}

########################################################
# 보안 설정 정보
########################################################

output "security_config" {
  value = {
    security_groups = {
      bastion_sg = {
        name = samsungcloudplatformv2_security_group_security_group.bastion_sg.name
        id   = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
        vpc  = "VPC1"
      }
      ceweb_sg = {
        name = samsungcloudplatformv2_security_group_security_group.ceweb_sg.name
        id   = samsungcloudplatformv2_security_group_security_group.ceweb_sg.id
        vpc  = "VPC1"
      }
      bbweb_sg = {
        name = samsungcloudplatformv2_security_group_security_group.bbweb_sg.name
        id   = samsungcloudplatformv2_security_group_security_group.bbweb_sg.id
        vpc  = "VPC2"
      }
    }
    firewall_rules = {
      vpc1_firewall = samsungcloudplatformv2_vpc_internet_gateway.igw["VPC1"].id
      vpc2_firewall = samsungcloudplatformv2_vpc_internet_gateway.igw["VPC2"].id
    }
  }
  description = "Security configuration for cross VPC access control"
}

########################################################
# 수동 설치 안내
########################################################

output "manual_installation_guide" {
  value = {
    preparation_status = "Complete - Ready for manual web server installation"
    ready_files = {
      ceweb_server = "/home/rocky/z_ready2install_go2web-server"
      bbweb_server = "/home/rocky/z_ready2install_go2web-server"
    }
    installation_commands = {
      ceweb_server = "cd /home/rocky/ceweb/web-server && sudo bash install_web_server.sh"
      bbweb_server = "cd /home/rocky/ceweb/web-server && sudo bash bbweb_install_web_server.sh"
    }
    ssh_access = {
      bastion = "RDP to ${samsungcloudplatformv2_vpc_publicip.pips["PIP1"].id}:3389"
      ceweb_server = "SSH to rocky@${samsungcloudplatformv2_vpc_publicip.pips["PIP2"].id}"
      bbweb_server = "SSH to rocky@${samsungcloudplatformv2_vpc_publicip.pips["PIP3"].id}"
    }
  }
  description = "Manual installation guide for web servers"
}

########################################################
# 다음 단계 안내
########################################################

output "next_steps" {
  value = {
    step1 = {
      title = "Wait for VM Initialization"
      description = "Wait 5-10 minutes for all VMs to complete initialization"
      estimated_time = "5-10 minutes"
    }
    step2 = {
      title = "Verify Ready Files"
      description = "SSH to each web server and check for z_ready2install_go2web-server file"
      commands = [
        "cat /home/rocky/z_ready2install_go2web-server"
      ]
    }
    step3 = {
      title = "Install Web Servers"
      description = "Run installation scripts on both web servers"
      ce_web_command = "cd /home/rocky/ceweb/web-server && sudo bash install_web_server.sh"
      bb_web_command = "cd /home/rocky/ceweb/web-server && sudo bash bbweb_install_web_server.sh"
    }
    step4 = {
      title = "Configure Load Balancer"
      description = "Manually create Load Balancer for cross VPC load balancing"
      requirements = [
        "Create Load Balancer in VPC1 or VPC2",
        "Add both web servers as members",
        "Configure health checks",
        "Set up cross VPC connectivity"
      ]
    }
    step5 = {
      title = "Configure VPC Peering"
      description = "Set up VPC Peering between VPC1 and VPC2"
      requirements = [
        "Create VPC Peering connection",
        "Accept peering connection",
        "Update route tables",
        "Update security groups for cross VPC traffic"
      ]
    }
    step6 = {
      title = "Update Security Rules"
      description = "Add Firewall and Security Group rules for load balancer traffic"
      requirements = [
        "Allow Load Balancer to web server traffic",
        "Allow cross VPC communication",
        "Configure health check rules"
      ]
    }
  }
  description = "Step-by-step guide for completing cross VPC load balancing setup"
}

########################################################
# 확장 계획
########################################################

output "expansion_plan" {
  value = {
    current_architecture = "Basic Cross VPC Web Servers"
    expansion_options = {
      load_balancer = {
        description = "Add Load Balancer for automatic traffic distribution"
        requirements = ["Load Balancer creation", "Health check configuration", "Cross VPC routing"]
      }
      vpc_peering = {
        description = "Enable cross VPC communication"
        requirements = ["VPC Peering setup", "Route table updates", "Security rule updates"]
      }
      additional_servers = {
        description = "Add more web servers for higher availability"
        requirements = ["Additional VM creation", "Load Balancer member addition", "Scaling policies"]
      }
      monitoring = {
        description = "Add monitoring and alerting"
        requirements = ["CloudWatch setup", "Load Balancer monitoring", "Cross VPC network monitoring"]
      }
    }
  }
  description = "Plans for expanding the current setup to full production architecture"
}