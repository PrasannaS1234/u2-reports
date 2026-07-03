locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "jasper-reports"
    ManagedBy   = "terraform"
  })
}

resource "aws_ebs_volume" "jasper_reports" {
  availability_zone = var.availability_zone
  size              = var.ebs_size_gb
  type              = var.ebs_type
  encrypted         = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jasper-ebs"
  })
}

# Attach to an EXISTING EC2 instance
resource "aws_volume_attachment" "jasper_reports" {
  count = (var.create_ec2 && var.ec2_instance_id != "") ? 1 : 0

  device_name = var.device_name
  volume_id   = aws_ebs_volume.jasper_reports.id
  instance_id = var.ec2_instance_id

  stop_instance_before_detaching = true
}
