provider "aws" {
  region = "eu-west-1"
}

# find the default VPC (so we don't create a custom network)
data "aws_vpc" "default" {
  default = true
}

# list subnets in the default VPC (we'll pick the first one to get a subnet_id)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# pick a recent Amazon Linux 2 AMI (works across regions)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group that allows SSH and HTTP from anywhere
resource "aws_security_group" "web_sg" {
  name        = "terraform-demo-web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-demo-web-sg"
  }
}

# Single EC2 instance that will run a simple Apache (httpd) server via user_data
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro" # free tier eligible
  subnet_id     = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>Hello from Terraform EC2</h1><p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "terraform-demo-web"
  }
}

output "instance_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}
