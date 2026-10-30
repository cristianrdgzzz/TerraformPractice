# ============================================================================
# TERRAFORM CONFIGURATION FOR WEB SERVER CLUSTER WITH ALB AND ASG
# ============================================================================
# This example demonstrates a production-grade web server cluster that
# combines Auto Scaling Groups (ASG) with Application Load Balancer (ALB)
# using modern Launch Templates for high availability and scalability.
#
# KEY FEATURES:
# - Multi-AZ deployment for high availability (spreads instances across subnets)
# - Application Load Balancer (ALB) distributes traffic across instances
# - Auto Scaling Group automatically manages EC2 instance lifecycle
# - Launch Template (modern approach, replaces deprecated Launch Configuration)
# - Health checks ensure failed instances are replaced automatically
# - Security groups implement defense-in-depth with separate rules for ALB and instances
#
# ARCHITECTURE:
#   Internet Users
#        |
#        v (Port 80)
#   [ALB - Multi-AZ]
#        |
#        +---> [Instance 1 - AZ1, Port 8080] (managed by ASG)
#        |
#        +---> [Instance 2 - AZ2, Port 8080] (managed by ASG)
#        |
#        +---> [Instance N] (can scale to max_size)
#
# DEPLOYMENT:
#   1. terraform init     - Initialize working directory
#   2. terraform plan     - Preview changes
#   3. terraform apply    - Create/update resources
#   4. terraform destroy  - Clean up (careful with this!)
#
# SECURITY MODEL:
#   - ALB Security Group: Accepts HTTP/HTTPS from internet (0.0.0.0/0)
#   - Instance Security Group: Only accepts traffic from ALB on server_port
#   - This prevents direct public access to instances

terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# DATA SOURCES: Discover existing AWS infrastructure
# ============================================================================
# These data sources query AWS to find existing VPC and subnet information.
# This approach is more flexible than hardcoding VPC IDs.
#
# WHY USE DATA SOURCES:
# 1. Dynamic Discovery: Works across different AWS accounts and regions
# 2. Maintainability: No need to update values if AWS defaults change
# 3. Multi-AZ Support: aws_subnets automatically discovers all subnets in the VPC
# 4. Best Practice: Referenced in the official Terraform AWS Provider documentation
#
# These data sources will be moved to data.tf for better code organization.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ============================================================================
# SECURITY GROUPS: Network access control for ALB and EC2 instances
# ============================================================================
# Security Groups are stateful firewalls that control inbound and outbound
# traffic. This implementation follows the principle of least privilege:
# - ALB: Open to public internet (HTTP/HTTPS)
# - Instances: Only accept traffic from ALB on the web server port
#
# This prevents direct public access to instances and ensures all traffic
# flows through the ALB for load balancing and health checks.

# APPLICATION LOAD BALANCER SECURITY GROUP
# ==========================================
# INBOUND RULES:
# - Port 80 (HTTP):   From anywhere (0.0.0.0/0) for web traffic
# - Port 443 (HTTPS): From anywhere (0.0.0.0/0) for secure traffic
#
# OUTBOUND RULES:
# - All traffic: To anywhere (needed for health checks to instances)
#
# NOTE: You should add HTTPS support in production by:
#   1. Getting an SSL certificate from AWS Certificate Manager (ACM)
#   2. Adding an HTTPS listener with certificate_arn
#   3. Optionally redirecting HTTP to HTTPS

resource "aws_security_group" "alb" {
  name        = var.alb_security_group_name
  description = "Security group for the Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # INBOUND: HTTP from public internet
  # Used by clients to access the web application
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to internet
  }

  # INBOUND: HTTPS from public internet (for future use)
  # Uncomment when SSL certificate is available
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to internet
  }

  # OUTBOUND: All traffic to anywhere
  # Required for:
  # 1. Sending requests to EC2 instances on port 8080
  # 2. Performing health checks
  # 3. DNS resolution
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"] # To anywhere
  }

  tags = {
    Name = var.alb_security_group_name
  }
}

# EC2 INSTANCE SECURITY GROUP
# ============================
# INBOUND RULES:
# - Port 8080: ONLY from ALB security group (restricted access)
#
# OUTBOUND RULES:
# - All traffic: To anywhere (for updates, downloads, etc.)
#
# KEY SECURITY BENEFIT:
# By using security_groups (instead of cidr_blocks), instances can ONLY
# receive traffic from the ALB. They are not accessible directly from the
# internet, even if they have public IP addresses. This is defense-in-depth.
#
# MULTI-AZ SUPPORT:
# Since instances are spread across multiple AZs, the ALB's security group
# is automatically allowed to reach instances in all AZs. AWS handles this
# transparently because both resources reference the same VPC.

resource "aws_security_group" "instance" {
  name        = var.instance_security_group_name
  description = "Security group for EC2 instances in the ASG"
  vpc_id      = data.aws_vpc.default.id

  # INBOUND: Web server port ONLY from ALB
  # This ensures instances only accept traffic from the load balancer
  # and not directly from the internet
  # Protocol: TCP on the web server port (variable, default 8080)
  # Source: ALB security group (other resources with that SG can send traffic)
  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Only from ALB
  }

  # OUTBOUND: All traffic to anywhere
  # Required for:
  # 1. Package manager updates (yum, apt)
  # 2. External API calls
  # 3. DNS resolution
  # 4. NTP time synchronization
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"] # To anywhere
  }

  tags = {
    Name = var.instance_security_group_name
  }
}

# ============================================================================
# LAUNCH TEMPLATE
# ============================================================================

resource "aws_launch_template" "example" {
  name_prefix   = "terraform-webserver-"
  description   = "Launch template for web server instances in ASG with ALB"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
    delete_on_termination       = true
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum install -y busybox
              echo "<h1>Hello from $(hostname -f)</h1>" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "terraform-webserver-lt"
  }
}

# ============================================================================
# AUTO SCALING GROUP
# ============================================================================

resource "aws_autoscaling_group" "example" {
  name                = "terraform-asg-example"
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  target_group_arns         = [aws_lb_target_group.asg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 30

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# APPLICATION LOAD BALANCER
# ============================================================================

resource "aws_lb" "example" {
  name               = var.alb_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = false

  tags = {
    Name = var.alb_name
  }
}

# ============================================================================
# ALB LISTENER AND TARGET GROUP
# ============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

resource "aws_lb_target_group" "asg" {
  name        = var.target_group_name
  port        = var.server_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = var.target_group_name
  }
}
