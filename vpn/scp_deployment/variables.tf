########################################################
# 수강자 입력 항목
########################################################
variable "keypair_name" {
  type        = string
  description = "Key Pair to access VM"
  default     = "mykey"                                 # 기존 Key Pair 이름으로 변경
}

variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "0.0.0.0"                           # 수강자 PC의 Public IP 주소 입력
}

########################################################
# VM Private IP 주소
########################################################
variable "bastion_ip" {
  type        = string
  description = "Private IP address of Bastion Host"
  default     = "10.1.1.10"                           
}

variable "nfsvm_ip" {
  type        = string
  description = "Private IP address of VM for NFS"
  default     = "10.1.1.20"                           
}


########################################################
# VPC 변수 정의
########################################################
variable "vpcs" {
  description = "VPC for Creative Energy"
  type = list(object({
    name        = string
    cidr        = string
    description = optional(string)
  }))
  default = [
    {
      name        = "VPC1"
      cidr        = "10.1.0.0/16"
      description = "Primary VPC"
    }
  ]
}

########################################################
# Subnet 변수 정의
########################################################
variable "subnets" {
  description = "Subnet for Creative Energy"
  type = list(object({
    name        = string
    cidr        = string
    type        = string                                  # GENERAL | LOCAL | VPC_ENDPOINT
    vpc_name    = string   
    description = string
  }))
  default = [
    {
      name        = "Subnet11"
      cidr        = "10.1.1.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "Subnet for Creative Energy"
    }
  ]
}

########################################################
# Public IP 변수 정의
########################################################

variable "public_ips" {
  type = list(object({
    name        = string
    description = string
  }))
  default = [
    { name = "PIP1", description = "Public IP for VM" },
    { name = "PIP2", description = "Public IP for VM" }
  ]
}

########################################################
# Security Group 변수 정의
########################################################
variable "security_group_bastion" {
    type        = string
    default     = "bastionSG"
  }

variable "security_group_web" {
    type        = string
    default     = "nfsvmSG"
  }

########################################################
# Virtual Server Standard Image 변수 정의
########################################################
variable "image_windows_os_distro" {
  type        = string
  default     = "windows"
}

variable "image_windows_scp_os_version" {
  type        = string
  default     = "2022 Std."
}

variable "image_rocky_os_distro" {
  type        = string
  default     = "rocky"
}

variable "image_rocky_scp_os_version" {
  type        = string
  default     = "9.4"
}

########################################################
# Virtual Server 변수 정의
########################################################

variable "server_type_id" {
  type    = string
  default = "s1v1m2"
}

variable "vm_bastion" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "vm110w"
    description = "Bastion Host"
  }
}

variable "boot_volume_windows" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  default = {
    size                  = 32
    type                  = "SSD"
    delete_on_termination = true
  }
}

variable "vm_nfsvm" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "vm111r"
    description = "VM for NFS"
  }
}

variable "boot_volume_rocky" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  default = {
    size                  = 16
    type                  = "SSD"
    delete_on_termination = true
  }
}
