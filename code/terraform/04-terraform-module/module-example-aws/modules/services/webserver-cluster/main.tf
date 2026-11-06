# ---------------------------------------------------------------------------
# Module: webserver-cluster - Main Terraform configuration
#
# This file defines the resources required to run a simple web-server cluster
# behind an Application Load Balancer (ALB) and an Auto Scaling Group (ASG).
# It is intentionally simple for learning purposes; production modules should
# include more robust networking, tagging, IAM, and lifecycle considerations.
# ---------------------------------------------------------------------------

terraform {
  # Enforce a range of Terraform versions compatible with the examples
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    # We depend on the AWS provider to provision resources in an AWS account.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


# ---------------------------------------------------------------------------
# Data sources and locals
# - We look up the default VPC / subnets so the example can run without
#   requiring the caller to pass VPC ids. For production modules it's
#   recommended to accept VPC/subnet IDs as inputs instead.
# - We also read remote state for the database to show how modules can
#   integrate with outputs produced by other stacks.
# ---------------------------------------------------------------------------

data "aws_vpc" "default" {
  # Use the default VPC in the account/region (convenient for examples).
  default = true
}

data "aws_subnets" "default" {
  # Select all subnets that belong to the default VPC. The ASG and ALB
  # will place resources into these subnets.
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Local values assigning names to expressions, so you can use these multiple times without repetitions
# These are visible only within this module -> they have no impact on other modules or calling code
locals {
  # Common network and protocol values used across security group rules
  http_port    = 80            # ALB listens on port 80 (external)
  any_port     = 0             # used to represent all ports for egress
  any_protocol = "-1"          # AWS convention for all protocols
  tcp_protocol = "tcp"         # tcp protocol for ingress rules
  all_ips      = ["0.0.0.0/0"] # open to the world (example only)

  # Other examples
  # vpc_name = "${var.cluster_name}-vpc"
  # subnet_tags = { "Name" = "${var.cluster_name}-subnet"
}

# Remote state: read outputs from a separate database stack
data "terraform_remote_state" "db" {
  # The remote backend is S3 in this example. The calling code (prod/stage)
  # must provide the S3 bucket and key that contain the DB stack state.
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2" # region is hard-coded for the example
  }
}


# ---------------------------------------------------------------------------
# Security groups
# - `aws_security_group.alb` is attached to the Application Load Balancer and
#   allows inbound HTTP from the public internet and outbound traffic to any
#   destination (for simplicity). In production you would scope this tighter.
# - `aws_security_group.instance` is attached to EC2 instances launched by the
#   ASG and allows ingress from the instance port (server_port). The ASG
#   instances accept traffic forwarded by the ALB target group.
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  # Security group for the load balancer
  name = "${var.cluster_name}-alb"
}

# Better separate resources than inline multiple rules in one resource (attached to the res)
# SECURITY TIP: Do not use cidr_blocks = [“0.0.0.0/0”] for aws_security_group.instance 
# if the intention is for only the ALB to access instances. Instead, allow traffic from the ALB's SG:
#   - Avoid expose of the instances to the Internet.
#   - Keep the rules that pertains to the module isolated and managed by the module.

resource "aws_security_group_rule" "allow_http_inbound" {
  # Allow HTTP (80) from Any -> ALB
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  # Allow ALB to make outbound connections to any address/port. Many
  # environments restrict outbound egress; this example keeps it open.
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group" "instance" {
  # Security group for the EC2 instances running the web server
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
  # Allow traffic on the application server port from any source. In a real
  # deployment you would restrict this to the ALB security group only.
  type              = "ingress"
  security_group_id = aws_security_group.instance.id

  from_port   = var.server_port
  to_port     = var.server_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}


# ---------------------------------------------------------------------------
# Launch configuration and Auto Scaling Group
# - `aws_launch_configuration` defines the EC2 instance configuration used by
#    the ASG (AMI, instance type, user-data, security groups).
# - `aws_autoscaling_group` controls the desired/min/max instance counts and
#    attaches the instances to the ALB target group.
# ---------------------------------------------------------------------------

#################################################################
# Launch configuration (commented)                                   #
# The block below shows the original `aws_launch_configuration` used in   #
# earlier versions of this example. It's left here commented for readers  #
# and for historical reference. In modern AWS, prefer `aws_launch_template` #
# which provides more features (e.g., multiple versions, mixed instances).  #
#################################################################

# resource "aws_launch_configuration" "example" {
#   # NOTE: Launch configurations are an older construct; in modern AWS you may
#   # prefer launch templates (aws_launch_template). This example used
#   # aws_launch_configuration to keep the module simple and focused on
#   # illustrating modules in Terraform.
#
#   image_id        = "ami-0fb653ca2d3203ac1"
#   instance_type   = var.instance_type
#   security_groups = [aws_security_group.instance.id]
#
#   # Inject a small user-data script into instances using templatefile(). The
#   # template substitutes server_port and DB connection details obtained from
#   # the remote state. This demonstrates passing dynamic values into instance
#   # initialization.
#   user_data = templatefile("${path.module}/user-data.sh", {
#     server_port = var.server_port
#     db_address  = data.terraform_remote_state.db.outputs.address
#     db_port     = data.terraform_remote_state.db.outputs.port
#   })
#
#   # Ensure instances are replaced gracefully when the launch configuration
#   # changes (create before destroy). This reduces downtime during updates.
#   lifecycle {
#     create_before_destroy = true
#   }
# }

#################################################################
## Replace with aws_launch_template (recommended)                 #
## - Launch templates are newer and support versioning, mixed instances,#
##   and more flexible networking options.
#################################################################

resource "aws_launch_template" "example" {
  # A short name prefix for the template. The full name will include
  # a random suffix generated by Terraform to avoid name collisions.
  name_prefix = "${var.cluster_name}-lt-"

  # Example AMI; callers should replace this by using a variable or a
  # `data "aws_ami"` lookup appropriate for the platform/region.
  image_id      = "ami-0fb653ca2d3203ac1"
  instance_type = var.instance_type

  # network_interfaces block allows attaching security groups by id
  network_interfaces {
    security_groups = [aws_security_group.instance.id]
  }

  # NOTE: path reference notes [path.<TYPE>]
  # path.module gives the filesystem path of the current module
  # path.root gives the filesystem path of the ROOT module (calling code)
  # path.cwd gives the current working directory of the terraform process
  #          same as path.root, but some uses of Terraform run it from a 
  #          directory other than the root module directory,
  #          causing these paths to be different

  # Provide user-data via templatefile() as before. The aws_launch_template
  # resource accepts raw user_data and the provider will base64-encode it
  # into the launch template as required by EC2.
  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })

  # Use lifecycle meta-argument to prefer creating the new template prior to
  # destroying an old one. This can reduce downtime when updating template
  # settings, though the ASG will still need to roll instances to pick up
  # the new version.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  # Use a launch_template block to reference the Launch Template created
  # above. This is the modern approach and allows specifying the template
  # id and version; here we use the latest version.
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
  # launch_configuration = aws_launch_configuration.example.name

  # Place instances in the discovered subnets
  vpc_zone_identifier = data.aws_subnets.default.ids

  # Attach instances to the ALB target group so the ALB can forward requests
  target_group_arns = [aws_lb_target_group.asg.arn]

  # Let the ALB manage health checks
  health_check_type = "ELB"

  # Scale boundaries are provided by the caller via variables
  min_size = var.min_size
  max_size = var.max_size

  # Tag instances with a human readable Name
  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}


# ---------------------------------------------------------------------------
# Application Load Balancer (ALB), listener and target group
# - The ALB listens on port 80 and forwards requests to the ASG target group.
# - Listener has a default fixed-response returning a 404 when no rules match.
# ---------------------------------------------------------------------------

resource "aws_lb" "example" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn

  # Listen on standard HTTP port 80
  port     = local.http_port
  protocol = "HTTP"

  # Default behaviour: return a simple 404 text response. Listener rules with
  # higher priority can override this behaviour and forward requests to the
  # target group.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "asg" {
  # Target group defines the ports and protocol for forwarding traffic to
  # the instances registered by the ASG.
  name     = var.cluster_name
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  # Simple health check configuration that the ALB will use to determine
  # instance health and remove unhealthy instances from rotation.
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  # A basic listener rule that matches all paths and forwards them to the
  # ASG target group. Priority 100 gives room for callers to add higher
  # priority rules if needed.
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


# End of module

