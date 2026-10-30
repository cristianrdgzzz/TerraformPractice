# ================================================================================
# TERRAFORM CONFIGURATION AND PROVIDER SETUP
# ================================================================================
# This configuration deploys a web server cluster with auto-scaling and a
# load balancer. It reads database connection details from the remote state
# stored by the MySQL RDS configuration in ../data-stores/mysql.

terraform {
  # Specify the minimum and maximum Terraform versions allowed
  required_version = ">= 1.0.0, < 2.0.0"

  # Define required providers and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # ================================================================================
  # S3 BACKEND CONFIGURATION (PARTIAL - DRY APPROACH)
  # ================================================================================
  # UNCOMMENT WHEN READY FOR REMOTE STATE
  # This uses PARTIAL BACKEND CONFIGURATION to reduce copy-paste duplication.
  # The shared settings (bucket, region, dynamodb_table, encrypt) are defined
  # in the backend.hcl file at the project root.
  #
  # INITIALIZATION:
  # To initialize this module with the partial configuration, run:
  #   terraform init -backend-config=../../backend.hcl
  #
  # This approach:
  # ✓ Reduces duplication across modules
  # ✓ Makes it easy to change bucket/region in one place
  # ✓ Still allows unique 'key' for each module
  # ✓ Follows the DRY (Don't Repeat Yourself) principle
  #
  # IMPORTANT: Only the 'key' is defined here. The other settings
  # (bucket, region, dynamodb_table, encrypt) come from backend.hcl
  #
  # The state file path mirrors the folder structure:
  # - This file: stage/services/webserver-cluster/main.tf
  # - State file: stage/services/webserver-cluster/terraform.tfstate
  # This creates a 1:1 mapping between code layout and state file location.
  #
  # backend "s3" {
  #   key = "stage/services/webserver-cluster/terraform.tfstate"
  # }
  # The other settings (bucket, region, dynamodb_table, encrypt)
  # are provided via -backend-config=../../backend.hcl when running terraform init
}

# Configure the AWS provider to use the us-east-2 region
provider "aws" {
  region = "us-east-2"
}

# ================================================================================
# EC2 LAUNCH CONFIGURATION
# ================================================================================
# Defines the template for EC2 instances created by the Auto Scaling Group.
# The launch configuration specifies the AMI, instance type, security group,
# and initialization script (user data) for each instance.

resource "aws_launch_configuration" "example" {
  # AMI ID for Ubuntu Linux 20.04 LTS in us-east-2
  # You may need to change this if using a different region
  image_id = "ami-0fb653ca2d3203ac1"

  # Instance type determines the compute resources
  # t2.micro is eligible for AWS free tier
  instance_type = "t2.micro"

  # Associate the instance security group to allow traffic
  security_groups = [aws_security_group.instance.id]

  # Render the user data script as a template with variable substitution
  # This injects database connection details into the startup script
  user_data = templatefile("user-data.sh", {
    server_port = var.server_port
    # Read database address from the MySQL state file (remote state)
    db_address = data.terraform_remote_state.db.outputs.address
    # Read database port from the MySQL state file (remote state)
    db_port = data.terraform_remote_state.db.outputs.port
  })

  # Lifecycle rule: create new instance before destroying old one
  # This prevents downtime during Auto Scaling operations and updates
  lifecycle {
    create_before_destroy = true
  }
}

# ================================================================================
# AUTO SCALING GROUP
# ================================================================================
# Automatically manages a group of EC2 instances, scaling up or down based on
# demand while maintaining availability across multiple subnets.

resource "aws_autoscaling_group" "example" {
  # Reference the launch configuration to use as template for new instances
  launch_configuration = aws_launch_configuration.example.name

  # Spread instances across default VPC subnets for high availability
  vpc_zone_identifier = data.aws_subnets.default.ids

  # Associate with load balancer target group
  target_group_arns = [aws_lb_target_group.asg.arn]

  # Use ELB (Elastic Load Balancer) health checks to determine instance health
  health_check_type = "ELB"

  # Minimum number of instances to maintain
  min_size = 2

  # Maximum number of instances allowed
  max_size = 10

  # Tag all instances in the group
  tag {
    key   = "Name"
    value = "terraform-asg-example"
    # Propagate tag to instances launched by the ASG
    propagate_at_launch = true
  }
}

# ================================================================================
# INSTANCE SECURITY GROUP
# ================================================================================
# Controls inbound and outbound traffic for EC2 instances.
# Allows incoming HTTP requests on the server port from anywhere.

resource "aws_security_group" "instance" {
  # Security group name
  name = var.instance_security_group_name

  # Inbound rule: Allow HTTP traffic on the web server port
  ingress {
    from_port = var.server_port
    to_port   = var.server_port
    protocol  = "tcp"
    # Allow from any source (0.0.0.0/0)
    # In production, consider restricting to specific IPs or security groups
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ================================================================================
# APPLICATION LOAD BALANCER (ALB)
# ================================================================================
# Distributes incoming traffic across multiple EC2 instances.
# Operates at Layer 7 (Application) for content-based routing.

resource "aws_lb" "example" {
  # Load balancer name
  name = var.alb_name

  # Type of load balancer: "application" for HTTP/HTTPS routing
  load_balancer_type = "application"

  # Subnets across which to distribute the load balancer
  subnets = data.aws_subnets.default.ids

  # Security group controlling traffic to the load balancer
  security_groups = [aws_security_group.alb.id]
}

# ================================================================================
# ALB HTTP LISTENER
# ================================================================================
# Listens for incoming HTTP connections on port 80 and routes them to targets.
# A default action (404 response) is provided for unmatched requests.

resource "aws_lb_listener" "http" {
  # ARN of the load balancer to attach this listener to
  load_balancer_arn = aws_lb.example.arn

  # Port to listen on
  port = 80

  # Protocol to use
  protocol = "HTTP"

  # Default action: return a 404 response for requests not matching any rules
  # More specific rules (defined later) can override this default
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# ================================================================================
# ALB TARGET GROUP
# ================================================================================
# Groups EC2 instances that receive traffic from the load balancer.
# Defines how health checks are performed to ensure only healthy instances
# receive traffic.

resource "aws_lb_target_group" "asg" {
  # Target group name (must match ALB name for this example)
  name = var.alb_name

  # Port on which targets receive traffic
  port = var.server_port

  # Protocol for communication with targets
  protocol = "HTTP"

  # VPC in which the targets run
  vpc_id = data.aws_vpc.default.id

  # Health check configuration to determine instance health
  health_check {
    # URL path to check for health
    path = "/"

    # Protocol for the health check
    protocol = "HTTP"

    # HTTP status code that indicates a healthy response
    matcher = "200"

    # Interval between health checks (seconds)
    interval = 15

    # Timeout for each health check request (seconds)
    timeout = 3

    # Number of consecutive successful checks before marking unhealthy instance as healthy
    healthy_threshold = 2

    # Number of consecutive failed checks before marking healthy instance as unhealthy
    unhealthy_threshold = 2
  }
}

# ================================================================================
# ALB LISTENER RULE
# ================================================================================
# Routes requests matching specific conditions to the target group.
# This rule matches all paths and forwards traffic to the ASG instances.

resource "aws_lb_listener_rule" "asg" {
  # ARN of the listener to attach this rule to
  listener_arn = aws_lb_listener.http.arn

  # Priority determines rule evaluation order (lower number = higher priority)
  # This rule has priority 100, so it runs after any higher-priority rules
  priority = 100

  # Condition: match all paths
  condition {
    path_pattern {
      # "*" matches all paths
      values = ["*"]
    }
  }

  # Action: forward matching requests to the target group
  action {
    type = "forward"
    # Forward to the target group containing the ASG instances
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# ================================================================================
# ALB SECURITY GROUP
# ================================================================================
# Controls inbound and outbound traffic for the load balancer.
# Allows incoming HTTP traffic from anywhere and all outbound traffic.

resource "aws_security_group" "alb" {
  # Security group name
  name = var.alb_security_group_name

  # Inbound rule: Allow HTTP traffic on port 80 from anywhere
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # Allow from any source (0.0.0.0/0)
    # This is typical for a public-facing load balancer
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Allow all outbound traffic to any destination
  egress {
    from_port = 0
    to_port   = 0
    # "-1" means all protocols
    protocol = "-1"
    # Allow to any destination
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ================================================================================
# DATA SOURCES: REMOTE STATE AND VPC INFORMATION
# ================================================================================
# These data sources read infrastructure information from other Terraform
# states and AWS APIs, allowing this configuration to integrate with
# previously deployed resources.

# ================================================================================
# REMOTE STATE DATA SOURCE (MYSQL DATABASE)
# ================================================================================
# Reads the Terraform state file stored in S3 for the MySQL database.
# This allows us to access database outputs (address, port) for configuration.

data "terraform_remote_state" "db" {
  # Backend type: S3 (same location as where this database state is stored)
  backend = "s3"

  # Configuration for accessing the remote state
  config = {
    # S3 bucket containing the database state file
    bucket = var.db_remote_state_bucket
    # Path to the database's terraform.tfstate file within the bucket
    key = var.db_remote_state_key
    # AWS region where the S3 bucket is located
    region = "us-east-2"
  }
}

# ================================================================================
# AWS VPC DATA SOURCE
# ================================================================================
# Retrieves the default VPC for this AWS account.
# The default VPC exists automatically in every AWS account.

data "aws_vpc" "default" {
  # Filter to get the default VPC
  default = true
}

# ================================================================================
# AWS SUBNETS DATA SOURCE
# ================================================================================
# Retrieves all subnets in the default VPC.
# These subnets will be used to distribute the load balancer and instances.

data "aws_subnets" "default" {
  # Filter subnets by VPC ID
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}