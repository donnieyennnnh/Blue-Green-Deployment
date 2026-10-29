# main.tf — single-EC2 infrastructure for the Blue-Green-Deployment project.
#
# Builds:
#   VPC                           10.0.0.0/16
#   └── public subnet             10.0.1.0/24  (first AZ in the region)
#   └── internet gateway + route  → 0.0.0.0/0
#   └── security group            SSH from my_ip_cidr, 80/443 world-open
#   └── EC2 instance              Ubuntu 22.04 LTS, t3.micro, 8 GB gp3 root
#   └── aws_key_pair              registers the user's SSH public key
#
# Nothing billed hourly beyond the single EC2. No NAT, no ALB, no EIP.
# `terraform destroy` cleans it all up.

# ---- Data sources ----

# Latest Ubuntu 22.04 LTS from Canonical. owners[0] is Canonical's AWS acct.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Pick the first available AZ in the region. We only need one.
data "aws_availability_zones" "available" {
  state = "available"
}

# ---- Networking ----

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---- Security ----

resource "aws_security_group" "app" {
  # name_prefix (not name) lets create_before_destroy work when we change rules.
  name_prefix = "${var.project_name}-sg-"
  description = "SSH from my_ip, HTTP/HTTPS from the world"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP (Nginx will serve the app)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (reserved for Phase 8 TLS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (apt, Docker pulls, GHCR, Prometheus push)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_key_pair" "app" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---- Compute ----

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.app.key_name

  # 8 GB is comfortably within the 30 GB free-tier EBS allowance.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-app"
  }
}
