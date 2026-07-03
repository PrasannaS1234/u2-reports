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
