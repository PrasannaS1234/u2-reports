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

variable "ec2_instance_id" {
  type        = string
  description = "Existing EC2 instance ID. Leave empty when creating a new instance."
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

variable "mount_owner" {
  type        = string
  description = "POSIX user:group for the Jasper mount directory"
  default     = "ec2-user:ec2-user"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type when creating a new instance"
  default     = "t3.medium"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (required when creating a new EC2 instance)"
  default     = ""
}

variable "subnet_id" {
  type    = string
  default = ""
}

variable "security_group_id" {
  type        = string
  description = "Existing security group ID. Leave empty to let Terraform create one."
  default     = ""
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name (required for new instance)"
  default     = ""
}

variable "associate_public_ip" {
  type        = bool
  description = "Associate a public IP when creating EC2 in a public subnet"
  default     = true
}

variable "allowed_ssh_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed SSH access when Terraform creates the security group"
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
