# Jasper Reports on AWS EBS — Setup Guide

| Field | Value |
|-------|-------|
| **Project** | jew-trade-service |
| **Purpose** | Store `.jasper` report files on a persistent AWS EBS volume and load them from Spring Boot |
| **Spring property** | `report.path` |
| **Recommended mount path** | `/opt/jasper-reports/` |
| **Region (example)** | `ap-south-1` |

---

## Architecture

```
Your Local PC
      |
      | Upload (SCP / WinSCP)
      v
+--------------------------------------+
|          EC2 Instance                |
|                                      |
|  Spring Boot Application             |
|  (jew-trade-service)                 |
|                                      |
|  /opt/jasper-reports/                |
|      invoice.jasper                  |
|      purchase.jasper                 |
|      customer.jasper                 |
|      ...                             |
|                                      |
|   (Stored on AWS EBS Volume)         |
+--------------------------------------+
```

The EBS volume is attached to the EC2 instance and mounted at `/opt/jasper-reports`. The application reads report files from disk using `report.path`.

---

## How jew-trade-service loads reports today

This project already loads Jasper files from the filesystem (not classpath):

| Item | Location |
|------|----------|
| Property | `report.path` in `application-*.properties` |
| Java config | `ReportConstants.java` — `@Value("${report.path}")` |
| Loader | `JasperReportGeneratorService.java` — `JRLoader.loadObject(file)` |
| Current prod-style path | `/home/ubuntu/tekfilo/jewtrade/reports/jasper/` |

After EBS setup, point `report.path` to the mount:

```properties
report.path=/opt/jasper-reports/
```

> **Important:** `report.path` must end with `/` because subreports use `SUBREPORT_DIR` with the same base path.

---

## Important: EC2 vs ECS Fargate

| Deployment | EBS direct mount | Recommended storage |
|------------|------------------|---------------------|
| **EC2** (this guide) | Yes | EBS volume |
| **ECS Fargate** (current `.aws/dev/main.tf`) | No — Fargate tasks cannot attach EBS | **Amazon EFS** or bake reports into the image |

If you deploy on **ECS Fargate**, use EFS instead of EBS. This guide targets **EC2 + EBS** as requested. See [Appendix B](#appendix-b-ecs-fargate-use-efs-instead-of-ebs) for a short Fargate note.

---

## Recommended directory structure

```
/opt/jasper-reports/
│
├── invoice/
│   ├── invoice.jasper
│   └── invoice_summary.jasper
├── purchase/
│   └── purchase.jasper
├── customer/
│   └── customer.jasper
├── sales/
│   └── sales.jasper
├── stock/
│   └── stock.jasper
└── common/
    ├── header.jasper
    ├── footer.jasper
    └── logo.png
```

Copy your existing files from:

`src/main/resources/jasper/`

to the EBS mount on the server (or upload compiled `.jasper` only).

---

# Part 1 — Manual setup (AWS Console + SSH)

## Step 1 — Create an EBS volume

1. Sign in to the [AWS Console](https://console.aws.amazon.com/).
2. Go to **EC2 → Elastic Block Store → Volumes**.
3. Click **Create volume**.
4. Configure:
   - **Volume type:** `gp3`
   - **Size:** `20` GB or larger (adjust for report count)
   - **Availability Zone:** Must match your EC2 instance (e.g. `ap-south-1a`)
   - **Encryption:** Recommended (AWS managed key)
5. Click **Create volume**.

## Step 2 — Attach the volume to EC2

1. Select the new volume.
2. **Actions → Attach volume**.
3. Choose your EC2 instance.
4. Device name: `/dev/xvdf` (or `/dev/sdf` on some AMIs).
5. Click **Attach**.

## Step 3 — Connect to EC2

```bash
ssh -i my-key.pem ec2-user@<EC2_PUBLIC_IP>
```

Use `ubuntu@` if your AMI is Ubuntu.

## Step 4 — Verify the new disk

```bash
lsblk
```

Example:

```
NAME      SIZE
xvda       30G
xvdf       20G
```

`xvdf` is the new EBS volume (name may vary: `nvme1n1` on Nitro instances).

## Step 5 — Format the volume (first time only)

> Skip this if the volume was already formatted and contains data (e.g. restored from snapshot).

```bash
sudo mkfs.ext4 /dev/xvdf
```

On Nitro instances, use the NVMe name from `lsblk`, e.g. `/dev/nvme1n1`.

## Step 6 — Create mount directory

```bash
sudo mkdir -p /opt/jasper-reports
```

## Step 7 — Mount the EBS volume

```bash
sudo mount /dev/xvdf /opt/jasper-reports
```

Verify:

```bash
df -h | grep jasper
```

Example:

```
/dev/xvdf        20G  0% /opt/jasper-reports
```

## Step 8 — Persistent mount (`/etc/fstab`)

```bash
sudo blkid
```

Example output:

```
/dev/xvdf: UUID="1234-5678-abcd-efgh" TYPE="ext4"
```

Edit fstab:

```bash
sudo nano /etc/fstab
```

Add (replace UUID):

```
UUID=1234-5678-abcd-efgh /opt/jasper-reports ext4 defaults,nofail 0 2
```

Test:

```bash
sudo umount /opt/jasper-reports
sudo mount -a
df -h | grep jasper
```

## Step 9 — Upload Jasper files

### Option A — SCP (from your PC)

All `.jasper` in one folder:

```bash
scp -i my-key.pem *.jasper ec2-user@<EC2_PUBLIC_IP>:/opt/jasper-reports/
```

With subfolders:

```bash
scp -i my-key.pem -r src/main/resources/jasper/* ec2-user@<EC2_PUBLIC_IP>:/opt/jasper-reports/
```

### Option B — WinSCP (Windows)

1. Open WinSCP, connect with your `.pem` key.
2. Navigate to `/opt/jasper-reports`.
3. Drag and drop `.jasper` files (and subreports).

## Step 10 — Verify files

```bash
ls -l /opt/jasper-reports
```

## Step 11 — Set permissions

Run as the user that starts Spring Boot (e.g. `ubuntu`, `ec2-user`, or `appuser` from Docker):

```bash
sudo chown -R ubuntu:ubuntu /opt/jasper-reports
sudo chmod -R 755 /opt/jasper-reports
```

## Step 12 — Configure Spring Boot

In the profile used on that server (e.g. `application-prod.properties`):

```properties
report.path=/opt/jasper-reports/
```

Or via environment variable in systemd / Docker / ECS:

```bash
REPORT_PATH=/opt/jasper-reports/
```

(Spring maps `report.path` — set `report.path` in properties or `REPORT_PATH` only if you add relaxed binding; prefer `report.path` in properties.)

## Step 13 — Restart and test

1. Restart jew-trade-service.
2. Generate a known report from the UI or API.
3. Confirm logs show:

   `ClasspathResource found with given report name /opt/jasper-reports/<ReportName>.jasper`

## Updating reports later

1. Compile `.jrxml` → `.jasper` locally.
2. Copy the updated file to `/opt/jasper-reports/` (same path/name).
3. This app loads from disk on each request (`JRLoader.loadObject(file)`), so **no restart** is required unless you add caching later.

## Backup — EBS snapshot

1. **EC2 → Volumes** → select the Jasper EBS volume.
2. **Actions → Create snapshot**.
3. Schedule snapshots with **AWS Backup** or **Data Lifecycle Manager** for production.

---

# Part 2 — Terraform-only setup (EC2 + EBS)

Terraform can **create and attach** the EBS volume. **Formatting and mounting** on first boot are done via EC2 `user_data` (included below).

## Folder layout (suggested)

Create a dedicated Terraform stack (separate from ECS Fargate in `.aws/dev/`):

```
.aws/jasper-ebs/
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── main.tf          # EBS volume + attachment
├── ec2.tf           # optional: EC2 with user_data mount
└── outputs.tf
```

## `provider.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" { ... }  # recommended for team use
}

provider "aws" {
  region = var.region
}
```

## `variables.tf`

```hcl
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

variable "tags" {
  type    = map(string)
  default = {}
}
```

## `main.tf` — EBS volume + attachment

```hcl
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
  count = var.ec2_instance_id != "" ? 1 : 0

  device_name = var.device_name
  volume_id   = aws_ebs_volume.jasper_reports.id
  instance_id = var.ec2_instance_id

  # Detach volume before destroy (safer for data volumes)
  stop_instance_before_detaching = true
}
```

## `ec2.tf` — Optional: new EC2 with auto-mount via user_data

Use this **instead of** `ec2_instance_id` if you want Terraform to create the server and mount the volume on first boot.

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["alma-9-ami-*-x86_64"]
  }
}

resource "aws_instance" "jewtrade_app" {
  count = var.ec2_instance_id == "" ? 1 : 0

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/user_data_mount_ebs.sh", {
    device_name = var.device_name
    mount_path  = var.mount_path
    volume_id   = aws_ebs_volume.jasper_reports.id
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app"
  })
}

resource "aws_volume_attachment" "jasper_reports_new_instance" {
  count = var.ec2_instance_id == "" ? 1 : 0

  device_name = var.device_name
  volume_id   = aws_ebs_volume.jasper_reports.id
  instance_id = aws_instance.jewtrade_app[0].id
}
```

## `user_data_mount_ebs.sh` (template)

```bash
#!/bin/bash
set -euo pipefail

DEVICE="${device_name}"
MOUNT="${mount_path}"

# Wait for EBS device (Nitro may expose as /dev/nvme*n1)
for i in {1..30}; do
  if [ -b "$DEVICE" ] || ls /dev/nvme*n1 2>/dev/null; then
    break
  fi
  sleep 2
done

# Resolve actual block device if xvdf -> nvme
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
```

## `outputs.tf`

```hcl
output "ebs_volume_id" {
  value       = aws_ebs_volume.jasper_reports.id
}

output "ebs_volume_az" {
  value       = aws_ebs_volume.jasper_reports.availability_zone
}

output "mount_path" {
  value       = var.mount_path
}

output "report_path_for_spring" {
  value       = "${var.mount_path}/"
  description = "Set report.path in application properties"
}
```

## `terraform.tfvars` (example)

```hcl
region            = "ap-south-1"
project_name      = "jewtrade"
environment       = "prod"
availability_zone = "ap-south-1a"
ec2_instance_id   = "i-0123456789abcdef0"   # existing EC2
ebs_size_gb       = 30
device_name       = "/dev/xvdf"
mount_path        = "/opt/jasper-reports"

tags = {
  Team = "tekfilo"
}
```

## Terraform commands

```bash
cd .aws/jasper-ebs
terraform init
terraform plan
terraform apply
```

After `apply`:

1. If you only created volume + attachment (existing EC2), **SSH once** and run format/mount steps from Part 1 (Steps 5–8), **or** use the user_data approach on a new instance.
2. Upload `.jasper` files to `/opt/jasper-reports/`.
3. Set `report.path=/opt/jasper-reports/` and redeploy the app.

## EBS snapshot via Terraform (backup)

```hcl
resource "aws_ebs_snapshot" "jasper_reports" {
  volume_id   = aws_ebs_volume.jasper_reports.id
  description = "Jasper reports EBS snapshot ${local.name_prefix}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jasper-snapshot"
  })
}
```

Use `aws_dlm_lifecycle_policy` for automated daily snapshots in production.

---

# Part 3 — Spring Boot / deployment checklist

| Step | Action |
|------|--------|
| 1 | Mount EBS at `/opt/jasper-reports` |
| 2 | Copy all `.jasper` (+ subreports) to mount path |
| 3 | Set `report.path=/opt/jasper-reports/` in active profile |
| 4 | Ensure app user can read files (`755` / correct owner) |
| 5 | Restart service (first deploy only) |
| 6 | Test one invoice/report endpoint |
| 7 | Enable EBS snapshots |

### Docker on EC2 (optional)

Mount EBS on the host, bind-mount into the container:

```yaml
volumes:
  - /opt/jasper-reports:/opt/jasper-reports:ro
environment:
  - REPORT_PATH=/opt/jasper-reports/
```

In `application-prod.properties`:

```properties
report.path=/opt/jasper-reports/
```

---

# Appendix A — Troubleshooting

| Symptom | Cause | Fix |
|---------|--------|-----|
| `Report file not found` | Wrong `report.path` or missing file | `ls /opt/jasper-reports/`; match exact `.jasper` name |
| Permission denied | Wrong owner | `chown` to app user |
| Volume empty after reboot | Missing `/etc/fstab` | Add UUID entry, `mount -a` |
| Device not found | Nitro naming | Use `lsblk`, mount `/dev/nvme1n1` |
| Subreport not found | Missing trailing slash | Use `report.path=/opt/jasper-reports/` |

---

# Appendix B — ECS Fargate: use EFS instead of EBS

Your current Terraform (`.aws/dev/main.tf`) uses **ECS Fargate**. Fargate **cannot** attach an EBS volume to a task.

**Options:**

1. **Amazon EFS** — mount shared file system in the ECS task definition (`volume` + `mountPoints`), store Jasper files on EFS, set `report.path=/mnt/jasper/`.
2. **EC2 launch type** — run ECS on EC2 and attach EBS to the host (advanced).
3. **Include reports in the Docker image** — simple but requires rebuild for every report change.

For Fargate + EFS, add to task definition (conceptual):

```json
"volumes": [{
  "name": "jasper-reports",
  "efsVolumeConfiguration": {
    "fileSystemId": "fs-xxxxxxxx",
    "rootDirectory": "/jasper"
  }
}],
"mountPoints": [{
  "sourceVolume": "jasper-reports",
  "containerPath": "/opt/jasper-reports",
  "readOnly": true
}]
```

Environment:

```json
{ "name": "report.path", "value": "/opt/jasper-reports/" }
```

(Request a separate **EFS + Fargate Terraform guide** if you want this wired into `.aws/dev/main.tf`.)

---

# Appendix C — Quick reference

| Item | Value |
|------|-------|
| Spring property | `report.path` |
| EBS mount | `/opt/jasper-reports/` |
| App loader | `JasperReportGeneratorService` + `JRLoader.loadObject` |
| Local source (dev) | `src/main/resources/jasper/` |
| Terraform stack (suggested) | `.aws/jasper-ebs/` |
| Backup | EBS snapshots / AWS Backup |

---

*Document for jew-trade-service — Jasper reports on AWS EBS (EC2). Align `report.path` with your active Spring profile after mount.*
