# PowerShell 에러 처리 설정
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Terraform API 로깅 설정 함수
function Set-TerraformLogging {
    # 로그 디렉토리 생성
    if (-not (Test-Path "terraform_log")) {
        New-Item -ItemType Directory -Path "terraform_log" -Force | Out-Null
    }
    
    # 다음 trial 번호 찾기
    $trialNum = 1
    while (Test-Path "terraform_log\trial$('{0:D2}' -f $trialNum).log") {
        $trialNum++
    }
    
    $logFile = "terraform_log\trial$('{0:D2}' -f $trialNum).log"
    
    # Terraform 환경변수 설정 (모든 API 통신 로그 기록)
    $env:TF_LOG = "TRACE"
    $env:TF_LOG_PATH = $logFile
    
    Write-Host "✓ Terraform API logging enabled: $logFile" -ForegroundColor Cyan
    Write-Host "  - All provider API requests and responses will be logged" -ForegroundColor Gray
    Write-Host ""
    
    return $logFile
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Terraform Deployment Started" -ForegroundColor Green
Write-Host "Project: Cross VPC Load Balancing" -ForegroundColor Green
Write-Host "Architecture: Multi-VPC Web Servers" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow
Write-Host ""

# API 로깅 설정
$logFile = Set-TerraformLogging

try {
    # Check if main.tf exists
    if (-not (Test-Path "main.tf")) {
        throw "main.tf file not found. Please run script in terraform directory."
    }

    # Check if terraform is installed
    $terraformVersion = terraform version 2>$null
    if (-not $terraformVersion) {
        throw "Terraform is not installed or not in PATH"
    }
    Write-Host "✓ Terraform found: $($terraformVersion[0])" -ForegroundColor Green

    # Generate master_config.json from variables.tf using terraform console
    Write-Host "[0/4] Extracting variables from variables.tf using terraform console..." -ForegroundColor Cyan

    # First initialize terraform if needed
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
    }

    # Extract variables using terraform console with individual commands
    Write-Host "Reading variables from variables.tf..." -ForegroundColor Yellow
    
    # Function to safely get a terraform variable
    function Get-TerraformVariable {
        param($VarName)
        try {
            $result = echo "var.$VarName" | terraform console
            if ($LASTEXITCODE -eq 0) {
                return $result.Trim().Trim('"')
            }
            else {
                return $null
            }
        }
        catch {
            return $null
        }
    }

    # Get all variables individually 
    $variables = @{
        user_public_ip = Get-TerraformVariable "user_public_ip"
        keypair_name = Get-TerraformVariable "keypair_name"
        bastion_ip = Get-TerraformVariable "bastion_ip"
        ceweb1_ip = Get-TerraformVariable "ceweb1_ip"
        bbweb1_ip = Get-TerraformVariable "bbweb1_ip"
    }

    # DNS 변수는 Load Balancing에서 불필요 (상대 경로 사용)

    # Verify we got the essential variables
    $requiredVars = @("user_public_ip", "keypair_name", "bastion_ip", "ceweb1_ip", "bbweb1_ip")
    $missingVars = @()
    $requiredVars | ForEach-Object {
        if ([string]::IsNullOrEmpty($variables[$_])) {
            $missingVars += $_
        }
    }
    
    if ($missingVars.Count -gt 0) {
        throw "Failed to extract the following required variables: $($missingVars -join ', ')"
    }

    Write-Host "✓ Variables extracted successfully:" -ForegroundColor Green
    Write-Host "  User IP: $($variables.user_public_ip)" -ForegroundColor White
    Write-Host "  SSH Key: $($variables.keypair_name)" -ForegroundColor White
    Write-Host "  Bastion IP: $($variables.bastion_ip)" -ForegroundColor White
    Write-Host "  CE Web Server IP: $($variables.ceweb1_ip)" -ForegroundColor White
    Write-Host "  BB Web Server IP: $($variables.bbweb1_ip)" -ForegroundColor White
    Write-Host ""

    # Generate master_config.json with extracted variables
    Write-Host "Generating master_config.json with extracted values..." -ForegroundColor Cyan

    $masterConfig = @{
        config_metadata = @{
            version = "1.0.0"
            created = Get-Date -Format "yyyy-MM-dd"
            description = "Samsung Cloud Platform Cross VPC Load Balancing Master Configuration"
            generated_from = "variables.tf via terraform console"
            architecture = "Multi-VPC Load Balancing"
        }
        infrastructure = @{
            domain = @{
                "_comment" = "DNS 설정은 Load Balancing에서 불필요 - 사용자가 Load Balancer 생성 후 필요시 수동 추가"
            }
            network = @{
                vpc1_cidr = "10.1.0.0/16"
                vpc1_subnet_cidr = "10.1.1.0/24"
                vpc2_cidr = "10.2.0.0/16"
                vpc2_subnet_cidr = "10.2.1.0/24"
            }
            servers = @{
                bastion_ip = $variables.bastion_ip
                ceweb_server_ip = $variables.ceweb1_ip
                bbweb_server_ip = $variables.bbweb1_ip
            }
            load_balancer = @{
                service_ip = ""
                algorithm = "ROUND_ROBIN"
                health_check_enabled = $true
                session_persistence = "SOURCE_IP"
                "_comment" = "Load Balancer는 수동으로 추가 구성"
            }
        }
        application = @{
            ceweb_server = @{
                nginx_port = 80
                ssl_enabled = $false
                service_name = "Creative Energy Web"
                health_check_path = "/health"
            }
            bbweb_server = @{
                nginx_port = 80
                ssl_enabled = $false
                service_name = "Big Boys Web"
                health_check_path = "/health"
            }
        }
        security = @{
            firewall = @{
                allowed_public_ips = @("$($variables.user_public_ip)/32")
                ssh_key_name = $variables.keypair_name
            }
            ssl = @{
                certificate_path = "/etc/ssl/certs/certificate.crt"
                private_key_path = "/etc/ssl/private/private.key"
            }
            vpc_peering = @{
                vpc1_to_vpc2 = @{
                    enabled = $false
                    status = "manual_configuration_required"
                    "_comment" = "VPC Peering은 수동으로 구성 필요"
                }
            }
        }
        deployment = @{
            git_repository = "https://github.com/SCPv2/ceweb.git"
            git_branch = "main"
            auto_deployment = $false
            rollback_enabled = $false
            installation_mode = "manual"
            ready_files = @{
                ceweb = "z_ready2install_go2web-server"
                bbweb = "z_ready2install_go2web-server"
            }
        }
        monitoring = @{
            log_level = "info"
            health_check_interval = 30
            metrics_enabled = $true
            cross_vpc_monitoring = $true
        }
        user_customization = @{
            "_comment" = "사용자 직접 수정 영역"
            company_name = "Cross VPC Load Balancing Lab"
            admin_email = "admin@company.com"
            timezone = "Asia/Seoul"
            backup_retention_days = 7
        }
    }

    # Convert to JSON and save with error handling
    try {
        $jsonString = $masterConfig | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $jsonString | Out-File -FilePath "master_config.json" -Encoding UTF8 -ErrorAction Stop
        Write-Host "✓ master_config.json created successfully!" -ForegroundColor Green
    }
    catch {
        throw "Failed to create master_config.json: $_"
    }
    Write-Host ""

    # Step 1: Terraform Validate (skip init since we already did it)
    Write-Host "[1/3] Running terraform validate..." -ForegroundColor Cyan
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "terraform validate failed"
    }
    Write-Host "✓ Success: terraform validate completed" -ForegroundColor Green
    Write-Host ""

    # Step 2: Terraform Plan
    Write-Host "[2/3] Running terraform plan..." -ForegroundColor Cyan
    terraform plan -out=tfplan
    if ($LASTEXITCODE -ne 0) {
        throw "terraform plan failed"
    }
    Write-Host "✓ Success: terraform plan completed" -ForegroundColor Green
    Write-Host ""

    # Step 3: Terraform Apply (with confirmation and retry)
    Write-Host "[3/3] Ready to deploy infrastructure..." -ForegroundColor Cyan
    Write-Host "Warning: This will create real resources on Samsung Cloud Platform!" -ForegroundColor Yellow
    
    do {
        $confirmation = Read-Host "Do you want to continue? (y/N)"
        $confirmation = $confirmation.Trim().ToLower()
        
        if ($confirmation -eq 'y' -or $confirmation -eq 'yes' -or $confirmation -eq '네' -or $confirmation -eq 'ㅇ') {
            $proceed = $true
            break
        }
        elseif ($confirmation -eq 'n' -or $confirmation -eq 'no' -or $confirmation -eq '' -or $confirmation -eq '아니오' -or $confirmation -eq 'ㄴ') {
            $proceed = $false
            break
        }
        else {
            Write-Host "Invalid input. Please enter 'y' for yes or 'n' for no (Korean: '네' or '아니오')" -ForegroundColor Yellow
        }
    } while ($true)
    
    if ($proceed) {
        Write-Host "Starting terraform apply..." -ForegroundColor Cyan
        terraform apply --auto-approve tfplan
        if ($LASTEXITCODE -ne 0) {
            throw "terraform apply failed"
        }
        
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "Deployed Resources:" -ForegroundColor Yellow
        Write-Host "* VPC: 2개 (VPC1: 10.1.0.0/16, VPC2: 10.2.0.0/16)" -ForegroundColor White
        Write-Host "* Subnets: 2개 (각 VPC당 1개씩)" -ForegroundColor White
        Write-Host "* Security Groups: 3개 (bastion, ceweb, bbweb)" -ForegroundColor White
        Write-Host "* Virtual Servers: 3개 (Bastion, CE Web, BB Web)" -ForegroundColor White
        Write-Host "* Public IPs: 3개" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "1. Wait 5 minutes for system preparation" -ForegroundColor White
        Write-Host "2. SSH to web servers and run installation scripts manually:" -ForegroundColor White
        Write-Host "   - CE Web Server: cd /home/rocky/ceweb/web-server && sudo bash install_web_server.sh" -ForegroundColor Gray
        Write-Host "   - BB Web Server: cd /home/rocky/ceweb/web-server && sudo bash bbweb_install_web_server.sh" -ForegroundColor Gray
        Write-Host "3. Check for z_ready2install_go2web-server files in /home/rocky/" -ForegroundColor White
        Write-Host "4. Configure Load Balancer manually for Cross VPC setup" -ForegroundColor White
        Write-Host "5. Configure VPC Peering for Cross VPC communication" -ForegroundColor White
        Write-Host ""
        
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host "This log contains all provider API requests and responses" -ForegroundColor Gray
    }
    else {
        Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
    }
}
catch {
    Write-Host ""
    Write-Host "❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Make sure you're in the correct directory with main.tf" -ForegroundColor White
    Write-Host "2. Check if Terraform is installed: terraform version" -ForegroundColor White
    Write-Host "3. Verify variables.tf has all required variables" -ForegroundColor White
    Write-Host "4. Check Samsung Cloud Platform credentials" -ForegroundColor White
    Write-Host ""
    
    if ($logFile) {
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host "Check the log for detailed API communication errors" -ForegroundColor Gray
    }
    exit 1
}
finally {
    # Cleanup temporary files
    if (Test-Path "terraform.tfstate.backup") {
        Write-Host "Terraform state files present - deployment artifacts saved" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Gray