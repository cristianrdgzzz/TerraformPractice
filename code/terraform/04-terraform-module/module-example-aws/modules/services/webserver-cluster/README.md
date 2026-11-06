# Web server cluster module example

This folder contains a small example Terraform module that provisions a
cluster of web servers fronted by an Application Load Balancer (ALB) and
an Auto Scaling Group (ASG) in AWS. It is intentionally minimal and geared
towards teaching module structure and resource relationships.

The module:
- Deploys an ALB listening on port 80
- Creates a target group and listener rules that forward traffic to an ASG
- Launches EC2 instances using a launch configuration and a small `user-data` script
- Demonstrates reading values from a separate database stack using remote state

For background reading see Chapter 4, "How to Create Reusable Infrastructure
with Terraform Modules", of *Terraform: Up and Running*.

**Important:** This example uses permissive security group rules and the
default VPC/subnets for convenience. Do not reuse these open settings in
production environments without tightening network and security controls.

## Contents

- `main.tf` — module resources (ALB, Target Group, Listener, ASG, security groups)
- `variables.tf` — module inputs and defaults
- `outputs.tf` — values exported by the module
- `user-data.sh` — small example initialization script used by EC2 instances
- `ARCHITECTURE.md` — diagrams and flow explanation (new)

## Example usage

Modules are not meant to be applied directly. Instead, reference them from
environment-specific configurations. Example of a simple module call:

```hcl
module "webserver_cluster" {
	source = "../../modules/services/webserver-cluster"

	cluster_name           = "example-cluster"
	instance_type          = "t3.micro"
	min_size               = 1
	max_size               = 2

	# Remote state for a separate database stack (example values)
	db_remote_state_bucket = "my-terraform-state-bucket"
	db_remote_state_key    = "envs/prod/db/terraform.tfstate"
}
```

## Inputs (summary)

- `cluster_name` (string, required): Name used for resources and tagging.
- `instance_type` (string, required): EC2 instance type for servers.
- `min_size` (number, required): Minimum ASG instance count.
- `max_size` (number, required): Maximum ASG instance count.
- `db_remote_state_bucket` (string, required): S3 bucket containing DB remote state.
- `db_remote_state_key` (string, required): Path to the DB terraform state file.
- `server_port` (number, optional, default: `8080`): Port the app listens on.

## Outputs (summary)

- `alb_dns_name`: DNS name of the Application Load Balancer (use to access app)
- `asg_name`: Auto Scaling Group name
- `alb_security_group_id`: Security Group ID attached to the ALB

## Architecture diagram

See `ARCHITECTURE.md` for component and flow diagrams. A quick inline
overview (Mermaid):

```mermaid
flowchart LR
	User --> ALB[ALB (port 80)]
	ALB --> TG[Target Group]
	TG --> ASG[ASG -> EC2 Instances]
	ASG --> EC2[EC2 (busybox httpd)]
	EC2 --> DB[Database (remote state referenced)]
```

## Notes on remote state

The module reads database connection information from another Terraform
state file stored in S3 using the `terraform_remote_state` data source. To
use this module you must configure the `db_remote_state_bucket` and
`db_remote_state_key` variables to point at the database stack's state file.

## Next steps and suggestions

- Make networking explicit: accept `vpc_id` and `subnet_ids` as inputs.
- Use `aws_launch_template` instead of `aws_launch_configuration` for more
	modern instance configuration options.
- Replace permissive security group rules with least-privilege rules.

For examples showing how this module is consumed, see
`stage/services/webserver-cluster` and `prod/services/webserver-cluster`.