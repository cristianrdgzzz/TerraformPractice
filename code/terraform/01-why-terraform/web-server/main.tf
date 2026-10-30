# Configure Terraform version and AWS provider requirements
terraform {
  # Enforce Terraform version between 1.0.0 and 2.0.0
  required_version = ">= 1.0.0, < 2.0.0"

  # Define required provider versions and sources
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure AWS provider for the specified region
provider "aws" {
  region = "us-east-2"
}

# Create a security group to control inbound and outbound traffic
resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Security group for web server"

  # Ingress rule: Allow HTTP traffic on port 8080 from any IP address
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from any IP (restrict if needed for security)
  }

  # Ingress rule: Allow SSH traffic on port 22 from any IP address for remote administration
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound traffic without restrictions
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

# Create an EC2 instance with Apache2 web server
resource "aws_instance" "app" {
  # Instance type: t3.micro (eligible for AWS free tier)
  instance_type = "t3.micro"
  # Availability zone for instance placement
  availability_zone = "us-east-2a"
  # Amazon Linux 2 AMI image ID
  ami = "ami-0fb653ca2d3203ac1"
  # Associate the security group for network traffic control
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  # Automatically assign a public IP address to the instance
  associate_public_ip_address = true

  # User data script executed on instance startup
  user_data = <<-EOF
              #!/bin/bash
              # Update system packages
              sudo apt-get update
              # Install Apache2 web server
              sudo apt-get install -y apache2

              # Create custom index.html with "Hello World! It works!" message
              sudo bash -c 'echo "Hello World! It works!" > /var/www/html/index.html'

              # Reconfigure Apache to listen on port 8080 instead of default port 80
              sudo sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
              # Update virtual host configuration to use port 8080
              sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-enabled/000-default.conf

              # Restart Apache2 to apply configuration changes
              sudo systemctl restart apache2
              EOF

  # Add tags for resource identification
  tags = {
    Name = "web-server-app"
  }
}

# Output the public IP address of the instance for easy access
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance for accessing the web server"
  value       = aws_instance.app.public_ip
}