## Staging: Webserver Cluster - Architecture

This environment folder calls the `webserver-cluster` module with staging
defaults (smaller instances, conservative scaling). It demonstrates how an
environment can add testing-focused security rules on top of the module.

```mermaid
flowchart LR
  User --> ALB[ALB (port 80)]
  ALB --> TG[Target Group]
  TG --> ASG[ASG -> EC2 Instances (module)]
  ASG --> EC2[EC2 Instances]
  EC2 --> DB[(MySQL database - separate stack)]
```

Notes:
- The `allow_testing_inbound` security rule in `main.tf` demonstrates how
  environment wrappers can add policies that reference module outputs.
