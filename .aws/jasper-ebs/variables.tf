variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "jewtrade"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "create_ec2" {
  type        = bool
  description = "When true, create or attach EC2. When false, only create the EBS volume."
  default     = false
}

# Existing EC2 instance to attach the volume to (if not creating EC2 in this module)
variable "ec2_instance_id" {
  type        = string
  description = "EC2 instance ID (e.g. i-0abc123def456)"
  default     = ""
}

variable "availability_zone" {
  type        = string
  description = "Must match EC2 instance AZ"
}

variable "ebs_size_gb" {
  type    = number
  default = 20
}

variable "ebs_type" {
  type    = string
  default = "gp3"
}

variable "device_name" {
  type    = string
  default = "/dev/xvdf"
}

variable "mount_path" {
  type    = string
  default = "/opt/jasper-reports"
}

# Required only when ec2_instance_id is empty (new EC2 in ec2.tf)
variable "subnet_id" {
  type    = string
  default = ""
}

variable "security_group_id" {
  type    = string
  default = ""
}

variable "key_name" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
