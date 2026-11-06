
# ---------------------------------------------------------------------------
# Module outputs
#
# These outputs expose the key information a caller typically needs after
# creating a webserver cluster: the ALB hostname, the Auto Scaling Group
# name, and the security group id for the load balancer.
# ---------------------------------------------------------------------------

output "alb_dns_name" {
  # The DNS name of the created Application Load Balancer. Useful to
  # configure DNS records or verify the endpoint.
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  # The Auto Scaling Group name. Can be used for monitoring, scaling
  # operations, or when referencing the group from other stacks.
  value       = aws_autoscaling_group.example.name
  description = "The name of the Auto Scaling Group"
}

output "alb_security_group_id" {
  # Security group id attached to the ALB. Callers may use this value
  # to create rules that rely on the ALB (e.g., allow-listing ALB IPs
  # for services in other VPCs).
  value       = aws_security_group.alb.id
  description = "The ID of the Security Group attached to the load balancer"
}

