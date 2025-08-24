#!/bin/bash
set -euxo pipefail

# Log all userdata execution
exec > >(tee /var/log/userdata_bbweb.log) 2>&1
echo "Big Boys Web Server preparation started: $(date)"

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
echo "Creating master_config.json for Big Boys Web Server..."
cat > /home/rocky/master_config.json << 'MASTER_CONFIG_EOF'
{
  "config_metadata": {
    "version": "1.0.0",
    "created": "$(date -I)",
    "description": "Big Boys Web Server Configuration for Cross VPC Load Balancing",
    "server_role": "bbweb_server",
    "architecture": "Multi-VPC Load Balancing"
  },
  "infrastructure": {
    "network": {
      "vpc1_cidr": "10.1.0.0/16",
      "vpc1_subnet_cidr": "10.1.1.0/24",
      "vpc2_cidr": "10.2.0.0/16",
      "vpc2_subnet_cidr": "10.2.1.0/24"
    },
    "servers": {
      "bastion_ip": "10.1.1.110",
      "ceweb_server_ip": "10.1.1.111", 
      "bbweb_server_ip": "10.2.1.211"
    }
  },
  "application": {
    "service_name": "Big Boys Web",
    "nginx_port": 80,
    "ssl_enabled": false,
    "health_check_path": "/health",
    "cross_vpc_peer": "10.1.1.111"
  },
  "deployment": {
    "installation_mode": "manual",
    "ready_file": "z_ready2install_go2web-server"
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

# Copy master config to web-server directory
echo "Setting up master configuration for web application..."
mkdir -p /home/rocky/ceweb/web-server
cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json

# Verify installation script exists
if [ -f /home/rocky/ceweb/web-server/bbweb_install_web_server.sh ]; then
    echo "✓ bbweb_install_web_server.sh found"
    chmod +x /home/rocky/ceweb/web-server/bbweb_install_web_server.sh
else
    echo "❌ bbweb_install_web_server.sh not found"
fi

# Test network connectivity to other VMs
echo "Testing network connectivity..."
ping -c 2 10.1.1.110 && echo "✓ Bastion (10.1.1.110) connectivity OK" || echo "❌ Bastion connectivity failed (Cross VPC)"
ping -c 2 10.1.1.111 && echo "✓ CE Web (10.1.1.111) connectivity OK" || echo "❌ CE Web connectivity failed (VPC Peering needed)"

# Create ready-to-install marker file
echo "Creating ready-to-install marker file..."
cat > /home/rocky/z_ready2install_go2web-server << 'READY_EOF'
Big Boys Web Server preparation completed: $(date)

=== Ready for Manual Installation ===

Server Role: Big Boys Web Server (VPC2)
Server IP: 10.2.1.211
Peer Server: Creative Energy Web Server (10.1.1.111)

Next steps:
1. SSH to this server (BB Web): ssh -i your-key.pem rocky@10.2.1.211
2. Run installation: cd /home/rocky/ceweb/web-server && sudo bash bbweb_install_web_server.sh
3. Verify service: curl http://localhost/health
4. Configure Load Balancer for cross VPC load balancing
5. Configure VPC Peering for cross VPC communication

Configuration file: /home/rocky/ceweb/web-server/master_config.json
Log file: /var/log/userdata_bbweb.log

=== Cross VPC Setup Required ===
- Load Balancer configuration
- VPC Peering setup
- Firewall rules for cross VPC traffic
- Security Group rules for load balancer

Note: This server is in VPC2, requires VPC Peering for communication with VPC1
READY_EOF

chown rocky:rocky /home/rocky/z_ready2install_go2web-server
chmod 644 /home/rocky/z_ready2install_go2web-server

# Verify repository structure
echo "Verifying repository structure..."
ls -la /home/rocky/ceweb/
ls -la /home/rocky/ceweb/web-server/

echo "Big Boys Web Server preparation completed: $(date)"
echo "Ready marker file created: /home/rocky/z_ready2install_go2web-server"