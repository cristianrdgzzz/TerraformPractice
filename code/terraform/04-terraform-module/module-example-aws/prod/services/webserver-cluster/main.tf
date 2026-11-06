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
  region = "us-east-2"
}

# ---------------------------------------------------------------------------
# Environment wrapper: production
#
# This file is a thin environment-specific wrapper that calls the
# `modules/services/webserver-cluster` module. The wrapper sets environment
# specific values such as instance size and scaling bounds, and defines
# scheduled scaling actions that operate against the module outputs.
#
# The module itself contains the ALB, target group and ASG. This wrapper
# demonstrates how to consume module outputs (e.g. `asg_name`) and add
# environment policies or schedules on top of the reusable module.
# ---------------------------------------------------------------------------

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  cluster_name           = var.cluster_name
  db_remote_state_bucket = var.db_remote_state_bucket
  db_remote_state_key    = var.db_remote_state_key

  instance_type = "m7i-flex.large" # Replaced m4.large to m7i-flex.large (aws free tier compatible)
  min_size      = 2
  max_size      = 10
}

# EXAMPLE OF USE CASES: Expose an extra port for health checks, testing,
# or monitoring; add scheduled scaling actions to adjust capacity during.

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  # Scheduled action that increases capacity during business hours.
  #
  # Fields:
  # - `scheduled_action_name`: A human friendly identifier for the scheduled action.
  # - `min_size`, `max_size`: Bounds that override the ASG's normal bounds while
  #    this scheduled action is in effect (the ASG will not scale outside these
  #    values while the schedule is active). These set the target bounds.
  # - `desired_capacity`: Explicit desired number of instances to set when the
  #    schedule executes. The ASG will attempt to reach this target subject to
  #    the provided min/max.
  # - `recurrence`: A cron-style expression (five fields) evaluated in UTC. The
  #    example `"0 9 * * *"` runs at 09:00 UTC every day. Convert to local
  #    timezone when planning schedules (or compute appropriate UTC times).
  # - `autoscaling_group_name`: The target ASG to apply the scheduled action to.
  #
  # Important behaviour notes:
  # - Recurrence rules fire at the cron-specified time in UTC. If you need a
  #   single one-off action, use `start_time` / `end_time` instead of `recurrence`.
  # - Multiple scheduled actions can overlap — the most recently executed
  #   scheduled action that sets `desired_capacity` will determine the ASG's
  #   desired capacity at that moment (subject to limits).
  # - Scheduled actions only set bounds/desired values; the ASG's dynamic
  #   scaling policies (if present) still operate within the updated bounds.
  scheduled_action_name = "scale-out-during-business-hours"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 10
  recurrence            = "0 9 * * *"

  autoscaling_group_name = module.webserver_cluster.asg_name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  # Scheduled action that reduces capacity after business hours.
  # This complements the `scale_out_during_business_hours` schedule and ensures
  # the ASG returns to a smaller footprint during lower-traffic hours.
  #
  # The `recurrence = "0 17 * * *"` expression runs at 17:00 UTC every day.
  # Remember to account for timezone differences when setting business-hour
  # schedules (for example, 09:00 local time may be a different UTC time).
  scheduled_action_name = "scale-in-at-night"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 2
  recurrence            = "0 17 * * *"

  autoscaling_group_name = module.webserver_cluster.asg_name
}


# ---------------------------------------------------------------------------
# Example scheduled actions (commented) — additional use-cases
#
# The following examples are commented out. They demonstrate other common
# scheduled-action patterns you can use with an Auto Scaling Group. Uncomment
# and adapt them in the environment wrapper that consumes the module (prod or
# stage) depending on your needs.
#
# 1) One-off maintenance window (single start_time/end_time)
#    Use `start_time` and `end_time` for a single, bounded window. Times must
#    be in RFC3339 format (UTC, e.g. "2025-12-25T02:00:00Z"). This example
#    increases capacity for a maintenance window.
#
#resource "aws_autoscaling_schedule" "maintenance_scale_up" {
#  scheduled_action_name = "maintenance-scale-up"
#  autoscaling_group_name = module.webserver_cluster.asg_name
#
#  # Target the ASG to 20 instances for the maintenance window
#  desired_capacity = 20
#  min_size = 20
#  max_size = 20
#
#  # One-off window (UTC)
#  start_time = "2025-12-25T02:00:00Z"
#  end_time   = "2025-12-25T06:00:00Z"
#}
#
# 2) Weekend scale-down (recurrence)
#    Reduce capacity across the weekend to save cost. Cron expression runs at
#    Saturday 00:00 UTC. Adjust the expression to match desired UTC times.
#
#resource "aws_autoscaling_schedule" "weekend_scale_down" {
#  scheduled_action_name = "weekend-scale-down"
#  autoscaling_group_name = module.webserver_cluster.asg_name
#
#  min_size = 0
#  max_size = 2
#  desired_capacity = 0
#
#  # This uses a cron expression evaluated in UTC. Example: run at 00:00 UTC
#  # on Saturdays. Modify cron fields for your schedule (all values are UTC).
#  recurrence = "0 0 * * SAT"
#}
#
# 3) Temporary load test for staging (start/end)
#    Use in `stage` to spin up extra capacity for a controlled load test window.
#
#resource "aws_autoscaling_schedule" "staging_load_test" {
#  scheduled_action_name = "staging-load-test"
#  autoscaling_group_name = module.webserver_cluster.asg_name
#
#  desired_capacity = 15
#  min_size = 15
#  max_size = 15
#
#  start_time = "2025-11-25T12:00:00Z"
#  end_time   = "2025-11-25T14:00:00Z"
#}
#
# Notes on mixing scheduled actions with dynamic scaling policies:
# - Scheduled actions set desired capacity and/or bounds at scheduled times.
# - If you also have dynamic scaling policies (target tracking or step scaling),
#   those policies continue to operate but are constrained by the scheduled
#   min/max. When the scheduled action ends (or another scheduled action runs),
#   policies will again control scaling within whatever bounds are current.
# - Be cautious: overlapping schedules can conflict. Order and timing determine
#   which scheduled action is in effect — using clear naming and non-overlapping
#   windows helps avoid surprises.
# ---------------------------------------------------------------------------

