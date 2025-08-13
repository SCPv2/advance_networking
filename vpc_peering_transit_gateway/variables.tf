########################################################
# 사용자 입력 항목
########################################################
variable "keypair_name" {
  type        = string
  description = "Key Pair to access VM"
  default     = "mykey"                                 # 기존 Key Pair 이름으로 변경
}

variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "00.00.00.00"                           # 사용자 PC의 Public IP 주소 입력
}

########################################################
# VM Private IP 주소
########################################################
variable "primary_ip" {
  type        = string
  description = "Private IP address of Primary VM"
  default     = "10.1.1.10"                           
}

variable "secondary_ip" {
  type        = string
  description = "Private IP address of Secondary VM"
  default     = "10.2.1.10"                           
}

variable "tertiary_ip" {
  type        = string
  description = "Private IP address of Tertiary VM"
  default     = "10.3.1.10"                           
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
    },
    {
      name        = "VPC2"
      cidr        = "10.2.0.0/16"
      description = "Secondary VPC"
    },
    {
      name        = "VPC3"
      cidr        = "10.3.0.0/16"
      description = "Tertiary VPC"
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
      description = "Primary Subnet"
    },
    {
      name        = "Subnet21"
      cidr        = "10.2.1.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC2"
      description = "Secondary Subnet"
    },
    {
      name        = "Subnet31"
      cidr        = "10.3.1.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC3"
      description = "Tertiary Subnet"
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
    { name = "PIP2", description = "Public IP for VM" },
    { name = "PIP3", description = "Public IP for VM" }
  ]
}

########################################################
# Security Group 변수 정의
########################################################
variable "security_group_primary" {
    type        = string
    default     = "primarySG"
  }

variable "security_group_secondary" {
    type        = string
    default     = "secondarySG"
  }

variable "security_group_tertiary" {
    type        = string
    default     = "tertiarySG"
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

variable "vm_primary" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "vm110w"
    description = "Primary VM"
  }
}

variable "vm_secondary" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "vm211r"
    description = "Secondary VM"
  }
}

variable "vm_tertiary" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "vm311r"
    description = "Tertiary VM"
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
