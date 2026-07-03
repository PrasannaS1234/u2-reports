region            = "ap-south-1"
project_name      = "jewtrade"
environment       = "dev"
availability_zone = "ap-south-1a"

# --- Create new EC2 + attach EBS (fully automated) ---
create_ec2      = true
ec2_instance_id = ""

# Replace with your VPC details (subnet AZ must match availability_zone above)
vpc_id    = "vpc-071ca12f1cdf39600"
subnet_id = "subnet-0a98fdc35e34d2fef"
key_name  = "mg-prod-runner"

instance_type           = "t3.medium"
associate_public_ip     = true
allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

ebs_size_gb = 30
ebs_type    = "gp3"
device_name = "/dev/xvdf"
mount_path  = "/opt/jasper-reports"
mount_owner = "ec2-user:ec2-user"

tags = {
  Team = "tekfilo"
}
