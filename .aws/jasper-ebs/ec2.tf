data "aws_ami" "amazon_linux" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["alma-9-ami-*-x86_64"]
  }
}

resource "aws_instance" "jewtrade_app" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  ami                    = data.aws_ami.amazon_linux[0].id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  user_data = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail

    DEVICE="${var.device_name}"
    MOUNT="${var.mount_path}"

    for i in {1..30}; do
      if [ -b "$DEVICE" ] || ls /dev/nvme*n1 2>/dev/null; then
        break
      fi
      sleep 2
    done

    if [ ! -b "$DEVICE" ]; then
      DEVICE=$(ls /dev/nvme*n1 | head -1)
    fi

    mkdir -p "$MOUNT"

    if ! blkid "$DEVICE"; then
      mkfs.ext4 -F "$DEVICE"
    fi

    UUID=$(blkid -s UUID -o value "$DEVICE")
    grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
    mount -a

    chown -R ec2-user:ec2-user "$MOUNT"
    chmod -R 755 "$MOUNT"
  SCRIPT

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app"
  })
}

resource "aws_volume_attachment" "jasper_reports_new_instance" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  device_name = var.device_name
  volume_id   = aws_ebs_volume.jasper_reports.id
  instance_id = aws_instance.jewtrade_app[0].id
}
