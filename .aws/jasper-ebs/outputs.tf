output "ebs_volume_id" {
  value = aws_ebs_volume.jasper_reports.id
}

output "ebs_volume_az" {
  value = aws_ebs_volume.jasper_reports.availability_zone
}

output "mount_path" {
  value = var.mount_path
}

output "report_path_for_spring" {
  value       = "${var.mount_path}/"
  description = "Set report.path in application properties"
}

output "ec2_instance_id" {
  value = var.create_ec2 ? (var.ec2_instance_id != "" ? var.ec2_instance_id : try(aws_instance.jewtrade_app[0].id, null)) : null
}

output "ec2_public_ip" {
  description = "Public IP of the new EC2 instance (for SSH / deploy)"
  value       = try(aws_instance.jewtrade_app[0].public_ip, null)
}

output "ec2_private_ip" {
  description = "Private IP of the new EC2 instance"
  value       = try(aws_instance.jewtrade_app[0].private_ip, null)
}

output "volume_attached" {
  description = "True when EBS volume is attached to EC2"
  value       = var.create_ec2 ? true : false
}

output "verify_commands" {
  description = "Run these on the instance (or via SSM) to confirm setup"
  value = {
    check_mount   = "df -h ${var.mount_path}"
    check_marker  = "test -f ${var.mount_path}/.jasper-ebs-ready && echo OK"
    list_reports  = "ls -la ${var.mount_path}"
    spring_config = "report.path=${var.mount_path}/"
  }
}
