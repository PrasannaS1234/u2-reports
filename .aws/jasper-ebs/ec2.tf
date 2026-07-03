data "aws_ami" "amazon_linux" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "jewtrade_app" {
  count = (var.create_ec2 && var.ec2_instance_id == "" && var.security_group_id == "") ? 1 : 0

  name        = "${local.name_prefix}-jasper-app-sg"
  description = "Security group for Jasper reports EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jasper-app-sg"
  })
}

resource "aws_iam_role" "ec2_jasper" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  name = "${local.name_prefix}-jasper-report-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  role       = aws_iam_role.ec2_jasper[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_jasper" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  name = "${local.name_prefix}-jasper-report-ec2-profile"
  role = aws_iam_role.ec2_jasper[0].name
}

locals {
  ec2_security_group_id = var.security_group_id != "" ? var.security_group_id : (
    length(aws_security_group.jewtrade_app) > 0 ? aws_security_group.jewtrade_app[0].id : ""
  )
}

resource "aws_instance" "jewtrade_app" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  ami                         = data.aws_ami.amazon_linux[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [local.ec2_security_group_id]
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = aws_iam_instance_profile.ec2_jasper[0].name
  associate_public_ip_address = var.associate_public_ip

  user_data = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail
    dnf install -y aws-cli
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  SCRIPT

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app"
  })

  lifecycle {
    precondition {
      condition     = var.subnet_id != ""
      error_message = "subnet_id is required when creating a new EC2 instance."
    }

    precondition {
      condition     = var.vpc_id != "" || var.security_group_id != ""
      error_message = "vpc_id is required when Terraform creates the security group."
    }

    precondition {
      condition     = var.key_name != ""
      error_message = "key_name is required when creating a new EC2 instance (for SSH deploy)."
    }
  }
}

resource "aws_volume_attachment" "jasper_reports_new_instance" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  device_name = var.device_name
  volume_id   = aws_ebs_volume.jasper_reports.id
  instance_id = aws_instance.jewtrade_app[0].id

  stop_instance_before_detaching = true
}
