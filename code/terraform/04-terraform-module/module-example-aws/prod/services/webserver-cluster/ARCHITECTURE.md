## Production: Webserver Cluster - Architecture

This environment folder calls the reusable `webserver-cluster` module and
adds production specific settings (instance sizing and scheduled scaling).

### Component diagram

```mermaid
flowchart LR
  User --> ALB[ALB (port 80)]
  ALB --> TG[Target Group]
  TG --> ASG[ASG -> EC2 Instances (module)]
  ASG --> EC2[EC2 Instances]
  EC2 --> DB[(MySQL database - separate stack)]
```

### Notes

- The wrapper configures `instance_type`, `min_size` and `max_size` before
  calling the module.
- Scheduled scaling actions in this folder use the `asg_name` output of the
  module to modify capacity on a schedule.
