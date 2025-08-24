#!/bin/bash
set -euxo pipefail

# Log all userdata execution
exec > >(tee /var/log/userdata_load_balancing.log) 2>&1
echo "Cross VPC Load Balancing setup started: $(date)"

# System update and basic packages
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y epel-release
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils jq

# Wait for network to be fully ready
echo "Waiting for network initialization..."
sleep 30

# Verify network connectivity
ping -c 3 8.8.8.8 || echo "Internet connectivity check failed"

# Create master configuration file
echo "Creating master_config.json..."
cat > /home/rocky/master_config.json << 'MASTER_CONFIG_EOF'
{
  "config_metadata": {
    "version": "1.0.0",
    "created": "${timestamp}",
    "description": "Samsung Cloud Platform Cross VPC Load Balancing Master Configuration",
    "generated_from": "terraform userdata via master_config.json.tpl",
    "architecture": "Multi-VPC Load Balancing"
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "${public_domain_name}",
      "private_domain_name": "${private_domain_name}",
      "private_hosted_zone_id": "${private_hosted_zone_id}"
    },
    "network": {
      "vpc1_cidr": "10.1.0.0/16",
      "vpc1_subnet_cidr": "10.1.1.0/24",
      "vpc2_cidr": "10.2.0.0/16",
      "vpc2_subnet_cidr": "10.2.1.0/24"
    },
    "servers": {
      "bastion_ip": "${bastion_ip}",
      "ceweb_server_ip": "${ceweb1_ip}",
      "bbweb_server_ip": "${bbweb1_ip}"
    },
    "load_balancer": {
      "service_ip": "",
      "algorithm": "ROUND_ROBIN",
      "health_check_enabled": true,
      "session_persistence": "SOURCE_IP",
      "_comment": "Load Balancer는 수동으로 추가 구성"
    }
  },
  "application": {
    "ceweb_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "service_name": "Creative Energy Web",
      "health_check_path": "/health"
    },
    "bbweb_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "service_name": "Big Boys Web",
      "health_check_path": "/health"
    }
  },
  "security": {
    "firewall": {
      "allowed_public_ips": ["${user_public_ip}/32"],
      "ssh_key_name": "${keypair_name}"
    },
    "ssl": {
      "certificate_path": "/etc/ssl/certs/certificate.crt",
      "private_key_path": "/etc/ssl/private/private.key"
    },
    "vpc_peering": {
      "vpc1_to_vpc2": {
        "enabled": false,
        "status": "manual_configuration_required",
        "_comment": "VPC Peering은 수동으로 구성 필요"
      }
    }
  },
  "deployment": {
    "git_repository": "https://github.com/SCPv2/ceweb.git",
    "git_branch": "main",
    "auto_deployment": false,
    "rollback_enabled": false,
    "installation_mode": "manual",
    "ready_files": {
      "ceweb": "z_ready2install_go2web-server",
      "bbweb": "z_ready2install_go2web-server"
    }
  },
  "monitoring": {
    "log_level": "info",
    "health_check_interval": 30,
    "metrics_enabled": true,
    "cross_vpc_monitoring": true
  },
  "user_customization": {
    "_comment": "사용자 직접 수정 영역",
    "company_name": "Cross VPC Load Balancing Lab",
    "admin_email": "admin@company.com",
    "timezone": "Asia/Seoul",
    "backup_retention_days": 7
  }
}
MASTER_CONFIG_EOF

# Set proper ownership
chown rocky:rocky /home/rocky/master_config.json
chmod 644 /home/rocky/master_config.json

# Clone application repository
echo "Cloning application repository..."
cd /home/rocky
if [ ! -d "ceweb" ]; then
    git clone https://github.com/SCPv2/ceweb.git
    chown -R rocky:rocky /home/rocky/ceweb
fi

# Copy master config to web-server directory for application use
echo "Setting up master configuration for web applications..."
mkdir -p /home/rocky/ceweb/web-server
cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json

# Verify installation scripts exist
if [ -f /home/rocky/ceweb/web-server/install_web_server.sh ]; then
    echo "✓ install_web_server.sh found"
else
    echo "❌ install_web_server.sh not found"
fi

if [ -f /home/rocky/ceweb/web-server/bbweb_install_web_server.sh ]; then
    echo "✓ bbweb_install_web_server.sh found"
else
    echo "❌ bbweb_install_web_server.sh not found"
fi

# Create ready-to-install marker file
echo "Creating ready-to-install marker file..."
cat > /home/rocky/z_ready2install_go2web-server << 'READY_EOF'
Web Server preparation completed: $(date)

=== Cross VPC Load Balancing Setup Ready ===

Next steps:
1. CE Web Server (10.1.1.111): Run 'sudo bash install_web_server.sh' in /home/rocky/ceweb/web-server/
2. BB Web Server (10.2.1.211): Run 'sudo bash bbweb_install_web_server.sh' in /home/rocky/ceweb/web-server/

After web server installation:
3. Configure Load Balancer manually for cross VPC load balancing
4. Configure VPC Peering for cross VPC communication
5. Update Firewall and Security Group rules for load balancer traffic

Configuration file: /home/rocky/ceweb/web-server/master_config.json
Log file: /var/log/userdata_load_balancing.log

=== Network Information ===
VPC1 (Creative Energy): 10.1.0.0/16
VPC2 (Big Boys): 10.2.0.0/16
Bastion: ${bastion_ip}
CE Web: ${ceweb1_ip}
BB Web: ${bbweb1_ip}
READY_EOF

chown rocky:rocky /home/rocky/z_ready2install_go2web-server
chmod 644 /home/rocky/z_ready2install_go2web-server

# Test network connectivity to other VMs
echo "Testing network connectivity..."
ping -c 2 ${bastion_ip} && echo "✓ Bastion connectivity OK" || echo "❌ Bastion connectivity failed"

# Verify git repository and files
echo "Verifying repository structure..."
ls -la /home/rocky/ceweb/
ls -la /home/rocky/ceweb/web-server/

echo "Cross VPC Load Balancing preparation completed: $(date)"
echo "Ready marker file created: /home/rocky/z_ready2install_go2web-server"