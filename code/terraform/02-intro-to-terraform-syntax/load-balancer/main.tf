# ============================================================================
# TERRAFORM CONFIGURATION FOR APPLICATION LOAD BALANCER (ALB)
# ============================================================================
# This example demonstrates how to create and configure an Application Load
# Balancer (ALB) that sits in front of an Auto Scaling Group (ASG) to
# distribute traffic across EC2 instances

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
  region = var.aws_region
}

# ============================================================================
# DATA SOURCES: Fetch existing AWS infrastructure information
# ============================================================================

# Data source: Lookup the default VPC in the AWS account
data "aws_vpc" "default" {
  default = true
}

# Data source: Lookup all subnets in the default VPC
# ALBs require subnets in multiple availability zones for high availability
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ============================================================================
# SECURITY GROUP FOR ALB
# ============================================================================

# Security group for the Application Load Balancer
# By default, all AWS resources don't allow any incoming or outgoing traffic,
# so we need to explicitly configure this security group
resource "aws_security_group" "alb" {
  name        = var.alb_security_group_name
  description = "Security group for the Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule: Allow inbound HTTP requests on port 80 from anywhere
  # This allows users to access the ALB
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule: Allow inbound HTTPS requests on port 443 from anywhere
  # This allows secure access to the ALB
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound traffic
  # This allows the ALB to perform health checks and forward traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.alb_security_group_name
  }
}

# ============================================================================
# APPLICATION LOAD BALANCER
# ============================================================================

# Create the Application Load Balancer (ALB)
# Note: AWS load balancers consist of multiple servers running in separate
# subnets (separate datacenters). AWS automatically scales the number of
# load balancer servers and handles failover, providing high availability
resource "aws_lb" "example" {
  # Name of the load balancer
  name = var.alb_name

  # Type of load balancer (application, network, or gateway)
  # Application Load Balancer is ideal for web applications
  load_balancer_type = "application"

  # Subnets where the ALB will run
  # Using all subnets in the Default VPC ensures multi-AZ deployment
  subnets = data.aws_subnets.default.ids

  # Security group to use for the ALB
  security_groups = [aws_security_group.alb.id]

  # Enable deletion protection to prevent accidental deletion
  enable_deletion_protection = false

  tags = {
    Name = var.alb_name
  }
}

# ============================================================================
# ALB LISTENER
# ============================================================================

# Create a listener for the ALB
# A listener checks for incoming traffic on a specified port and protocol
resource "aws_lb_listener" "http" {
  # Reference to the ALB
  load_balancer_arn = aws_lb.example.arn

  # Listen on port 80 (default HTTP port)
  port = 80

  # Use HTTP protocol
  protocol = "HTTP"

  # Default action: Return a simple 404 page for requests that don't match any rules
  # This is a fallback response
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

# ============================================================================
# TARGET GROUP
# ============================================================================

# Create a target group for the ALB
# A target group specifies where to route traffic (in this case, to ASG instances)
resource "aws_lb_target_group" "asg" {
  # Name of the target group
  name = var.target_group_name

  # Port on which targets listen
  port = var.server_port

  # Protocol for communication with targets
  protocol = "HTTP"

  # VPC where targets are located
  vpc_id = data.aws_vpc.default.id

  # Health check configuration
  # This determines whether instances are healthy and should receive traffic
  health_check {
    # Path to use for health checks
    path = "/"

    # Protocol for health checks
    protocol = "HTTP"

    # Expected HTTP status code for healthy instances
    matcher = "200"

    # How often to perform health checks (in seconds)
    interval = 15

    # How long to wait for a health check response (in seconds)
    timeout = 3

    # Number of consecutive successful health checks to mark instance as healthy
    healthy_threshold = 2

    # Number of consecutive failed health checks to mark instance as unhealthy
    unhealthy_threshold = 2
  }

  tags = {
    Name = var.target_group_name
  }
}

# ============================================================================
# ALB LISTENER RULE
# ============================================================================

# Create a listener rule to forward traffic to the target group
# This ties together the listener, rules, and target group
resource "aws_lb_listener_rule" "asg" {
  # Reference to the listener this rule applies to
  listener_arn = aws_lb_listener.http.arn

  # Priority of this rule (lower numbers are evaluated first)
  # 100 is a good default priority
  priority = 100

  # Conditions for when this rule applies
  # This rule matches all paths (*)
  condition {
    path_pattern {
      values = ["*"]
    }
  }

  # Action to take when the condition is met
  # Forward traffic to the target group
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# ============================================================================
# OPTIONAL: SECURITY GROUP FOR INSTANCES (To use with ASG)
# ============================================================================

# Security group for EC2 instances behind the ALB
# Instances should only accept traffic from the ALB (not from the internet)
resource "aws_security_group" "instance" {
  name        = var.instance_security_group_name
  description = "Security group for EC2 instances behind the ALB"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule: Allow traffic from ALB on the server port only
  # This ensures instances only accept traffic from the ALB
  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.instance_security_group_name
  }
}
