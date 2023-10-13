terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region                  = ""
  shared_credentials_file = "/path-to-your-aws-credentials" #Example for Ubuntu: /home/ubuntu/.aws/credentials
}

provider "cloudflare" {
  email   = ""
  api_key = ""
}

data "cloudflare_zone" "dptools" {
  name = "" # your domain... example: example.com
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "subdomain_value" {}
variable "plan" {
  default = ""
}
variable "newdomain_name" {
  default = ""
}

resource "aws_security_group" "myapp-sg" {
  name = "${var.subdomain_value}-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = [var.my_ip]
    prefix_list_ids = []
  }

  tags = {
    Name : "${var.subdomain_value}-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_eip" "example" {
  instance = aws_instance.myapp-server.id
  vpc      = true
}

resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.dptools.id
  name    = var.subdomain_value # This will be replaced with
  value   = aws_eip.example.public_ip
  type    = "A"
  proxied = true
}

resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  # instance state is "running" by default

  root_block_device {
    # if the var.plan is basic we set the volume size to 8GB, if it is standard we set it to 16GB, 
    # if it is premium we set it to 32GB
    volume_size           = var.plan == "premium" ? 32 : var.plan == "standard" ? 16 : 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

  # subnet_id              = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  # availability_zone      = var.avail_zone

  associate_public_ip_address = true
  key_name                    = "tf-key-pair"

  tags = {
    Name : "${var.subdomain_value}-server"
  }
}


output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

output "eip" {
  value = aws_eip.example.public_ip
}

output "domain_name" {
  value = cloudflare_record.www.name
}

output "newdomain_name" {
  value = var.newdomain_name
}
output "domain_ip" {
  value = cloudflare_record.www.value
}
