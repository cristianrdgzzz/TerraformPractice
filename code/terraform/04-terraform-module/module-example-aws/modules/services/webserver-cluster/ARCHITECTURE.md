## Webserver Cluster Architecture

This file provides simple diagrams and step-by-step flow for the
`webserver-cluster` module. Use these diagrams to understand how traffic
flows and how resources relate.

### Component diagram (Mermaid)

```mermaid
graph TD
  subgraph Internet
    User[User]
  end

  subgraph VPC
    ALB[Application Load Balancer]
    TG[Target Group]
    ASG[Auto Scaling Group]
    EC2[EC2 Instances]
    DB[(Database)]
  end

  User -->|HTTP 80| ALB
  ALB --> TG
  TG --> ASG
  ASG --> EC2
  EC2 -->|application connection| DB
```

### Request flow (sequence)

```mermaid
sequenceDiagram
  participant C as Client
  participant ALB as ALB
  participant TG as TargetGroup
  participant EC2 as EC2 Instance
  participant DB as Database

  C->>ALB: HTTP GET /
  ALB->>TG: Forward request
  TG->>EC2: Route to healthy instance
  EC2->>DB: (Optional) read config or data
  EC2-->>C: HTTP 200 (Hello, World)
```

### Notes

- The module uses a small `user-data` script that writes a single `index.html`
  and starts `busybox httpd`. It's a pedagogical example, not a production
  webserver setup.
- The module obtains DB address/port by reading a remote Terraform state.
- Security groups are open to the internet in this example to keep the
  configuration small and easy to run. Always restrict SGs for production.

### Recommended extensions

- Add `vpc_id` and `subnet_ids` inputs to avoid depending on the default VPC.
- Replace the launch configuration with a launch template and consider
  using an AMI parameter or data source to locate up-to-date AMIs.
