# Format, mount, and persist Jasper EBS after Terraform attaches the volume (no manual SSH).
resource "aws_ssm_document" "mount_jasper_ebs" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  name            = "${local.name_prefix}-mount-jasper-ebs"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Format and mount Jasper EBS volume"
    parameters = {
      DeviceName = { type = "String", default = var.device_name }
      MountPath  = { type = "String", default = var.mount_path }
      MountOwner = { type = "String", default = var.mount_owner }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "mountJasperEbs"
      inputs = {
        runCommand = split("\n", <<-SCRIPT
          #!/bin/bash
          set -euo pipefail
          DEVICE="{{ DeviceName }}"
          MOUNT="{{ MountPath }}"
          OWNER="{{ MountOwner }}"
          LOG=/var/log/jasper-ebs-mount.log
          exec > >(tee -a "$LOG") 2>&1
          echo "=== Jasper EBS mount started $(date -Is) ==="
          for i in $(seq 1 60); do
            if [ -b "$DEVICE" ] || ls /dev/nvme*n1 >/dev/null 2>&1; then break; fi
            sleep 10
          done
          if [ ! -b "$DEVICE" ]; then DEVICE=$(ls /dev/nvme*n1 2>/dev/null | grep -v nvme0n1 | head -1 || true); fi
          if [ -z "$DEVICE" ] || [ ! -b "$DEVICE" ]; then echo "ERROR: EBS device not found"; exit 1; fi
          mkdir -p "$MOUNT"
          if ! blkid "$DEVICE" >/dev/null 2>&1; then mkfs.ext4 -F "$DEVICE"; fi
          UUID=$(blkid -s UUID -o value "$DEVICE")
          grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
          mount -a
          chown -R "$OWNER" "$MOUNT"
          chmod -R 755 "$MOUNT"
          touch "$MOUNT/.jasper-ebs-ready"
          df -h "$MOUNT"
          ls -la "$MOUNT"
          echo "=== Jasper EBS mount complete $(date -Is) ==="
        SCRIPT
        )
      }
    }]
  })

  tags = local.common_tags
}

resource "time_sleep" "wait_for_ssm" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  depends_on = [aws_instance.jewtrade_app]

  create_duration = "90s"
}

resource "aws_ssm_association" "mount_jasper_ebs" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  name = aws_ssm_document.mount_jasper_ebs[0].name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.jewtrade_app[0].id]
  }

  parameters = {
    DeviceName = var.device_name
    MountPath  = var.mount_path
    MountOwner = var.mount_owner
  }

  depends_on = [
    aws_volume_attachment.jasper_reports_new_instance,
    time_sleep.wait_for_ssm,
  ]
}

resource "aws_ssm_document" "verify_jasper_ebs" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  name            = "${local.name_prefix}-verify-jasper-ebs"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Verify Jasper EBS mount and readiness marker"
    parameters = {
      MountPath = { type = "String", default = var.mount_path }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "verifyJasperEbs"
      inputs = {
        runCommand = [
          "MOUNT='{{ MountPath }}'",
          "test -f \"$MOUNT/.jasper-ebs-ready\" || { echo 'NOT READY: marker missing'; exit 1; }",
          "mountpoint -q \"$MOUNT\" || { echo 'NOT READY: not mounted'; exit 1; }",
          "df -h \"$MOUNT\"",
          "ls -la \"$MOUNT\"",
          "echo 'JASPER_EBS_VERIFY_OK'",
        ]
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_ssm_association" "verify_jasper_ebs" {
  count = (var.create_ec2 && var.ec2_instance_id == "") ? 1 : 0

  name = aws_ssm_document.verify_jasper_ebs[0].name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.jewtrade_app[0].id]
  }

  parameters = {
    MountPath = var.mount_path
  }

  depends_on = [aws_ssm_association.mount_jasper_ebs]
}
