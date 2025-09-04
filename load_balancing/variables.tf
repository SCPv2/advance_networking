########################################################
# 공통 태그 설정
########################################################
variable "common_tags" {
  type        = map(string)
  description = "Common tags to be applied to all resources"
  default = {
    name      = "advance_networking_lab"
    createdby = "terraform"
  }
}

########################################################
# 수강자 입력 항목
########################################################

variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "x.x.x.x"                                # 수강자 PC의 Public IP 주소 입력
}

variable "keypair_name" {
  type        = string
  description = "Key Pair to access VM"
  default     = "mykey"                                 # 기존 Key Pair 이름으로 변경
}

########################################################
# VM Private IP 주소 (Cross VPC Load Balancing)
########################################################
variable "bastion_ip" {
  type        = string
  description = "Private IP address of bastion VM"
  default     = "10.1.1.110"                           
}

variable "ceweb1_ip" {
  type        = string
  description = "Private IP address of Creative Energy web VM"
  default     = "10.1.1.111"                           
}

variable "bbweb1_ip" {
  type        = string
  description = "Private IP address of Big Boys web VM"
  default     = "10.2.1.211"                           
}

########################################################
# VPC 변수 정의 (2개 VPC for Cross VPC Load Balancing)
########################################################
variable "vpcs" {
  description = "VPCs for Cross VPC Load Balancing"
  type = list(object({
    name        = string
    cidr        = string
    description = optional(string)
  }))
  default = [
    {
      name        = "VPC1"
      cidr        = "10.1.0.0/16"
      description = "Creative Energy VPC"
    },
    {
      name        = "VPC2"
      cidr        = "10.2.0.0/16"
      description = "Big Boys VPC"
    }
  ]
}

########################################################
# Subnet 변수 정의 (각 VPC당 1개씩)
########################################################
variable "subnets" {
  description = "Subnets for Cross VPC Load Balancing"
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
      description = "Creative Energy Subnet"
    },
    {
      name        = "Subnet21"
      cidr        = "10.2.1.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC2"
      description = "Big Boys Subnet"
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
    { name = "PIP1", description = "Public IP for Bastion VM" },
    { name = "PIP2", description = "Public IP for Creative Energy Web VM" },
    { name = "PIP3", description = "Public IP for Big Boys Web VM" }
  ]
}

########################################################
# Security Group 변수 정의
########################################################
variable "security_group_bastion" {
    type        = string
    default     = "bastionSG"
  }

variable "security_group_ceweb" {
    type        = string
    default     = "cewebSG"
  }

variable "security_group_bbweb" {
    type        = string
    default     = "bbwebSG"
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
# Virtual Server 변수 정의 (Cross VPC 구성)
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
    name = "bastionvm110w"
    description = "Bastion VM for Cross VPC Access"
  }
}

variable "vm_ceweb1" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "cewebvm111r"
    description = "Creative Energy Web VM1"
  }
}

variable "vm_bbweb1" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "bbwebvm211r"
    description = "Big Boys Web VM1"
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

# Virtual Server Standard Image 변수 정의
variable "windows_image_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Windows Server image ID"
  default     = "28d98f66-44ca-4858-904f-636d4f674a62"
}

variable "rocky_image_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Rocky Linux image ID"
  default     = "253a91ea-1221-49d7-af53-a45c389e7e1a"
}