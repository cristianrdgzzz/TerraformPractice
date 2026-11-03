# Terraform File Layout Example

This folder demonstrates the **recommended file layout** for organizing Terraform code across multiple environments and components. This is the production-ready approach to structuring Terraform projects and is far superior to using workspaces for environment isolation.

## Why File Layout Over Workspaces?

While Terraform workspaces can be useful for quick testing, the **file layout approach** is the recommended pattern for production infrastructure because it provides:

- ✅ **Separate state files per environment** (different S3 buckets or keys)
- ✅ **Separate access controls** per environment
- ✅ **Clear visibility** of infrastructure in your codebase
- ✅ **Safe isolation** preventing accidental production changes
- ✅ **Easy team collaboration** with clear code organization

Workspaces, by contrast, store all state in the same backend and lack visibility, making them unsuitable for production use.

## Directory Structure

```
file-layout-example/
├── backend.hcl                              # Shared S3 backend configuration
├── BACKEND_SETUP.md                         # Backend configuration guide
├── README.md                                # This file
│
├── global/                                  # Resources used across ALL environments
│   └── s3/
│       ├── main.tf                          # S3 bucket & DynamoDB table for state
│       ├── variables.tf                     # Input variables
│       ├── outputs.tf                       # Output variables (bucket name, etc.)
│       └── README.md                        # Instructions for this module
│
└── stage/                                   # Pre-production (testing) environment
    ├── data-stores/                         # Data storage components
    │   └── mysql/
    │       ├── main.tf                      # MySQL RDS instance
    │       ├── variables.tf                 # Input variables
    │       ├── outputs.tf                   # Output variables
    │       └── README.md
    │
    └── services/                            # Application/microservice components
        └── webserver-cluster/
            ├── main.tf                      # ALB, ASG, web servers
            ├── variables.tf                 # Input variables
            ├── outputs.tf                   # Output variables
            └── README.md
```

## Understanding the Hierarchy

### Top Level: Environments

The top-level folders represent **distinct environments** with separate infrastructure:

- **`global/`** - Resources shared across all environments
  - S3 backend infrastructure
  - IAM roles and policies
  - VPC peering
  - DNS records
  - Any resource needed by multiple environments

- **`stage/`** - Pre-production (testing) environment
  - Staging/testing version of your applications
  - Smaller instances to save costs
  - Separate databases
  - Complete replica of production setup

- **`prod/`** - Production environment *(typically you add this)*
  - User-facing applications
  - Larger instances for scale
  - Production databases with backups
  - Extra security and monitoring

- **`mgmt/`** - DevOps/Management tools *(optional)*
  - Bastion host for SSH access
  - CI/CD servers (Jenkins, GitLab Runner)
  - Monitoring and logging infrastructure
  - Backup systems

### Middle Level: Components

Within each environment, folders organize by **component type**:

- **`data-stores/`** - Databases and data systems
  - MySQL/PostgreSQL
  - Redis/ElastiCache
  - DynamoDB
  - S3 buckets for app data

- **`services/`** - Applications and microservices
  - Web servers
  - API servers
  - Backend workers
  - Each service can have its own subfolder

- **`vpc/`** - Network infrastructure *(typically added)*
  - VPC configuration
  - Subnets
  - Route tables
  - Security groups
  - VPN connections

### Bottom Level: Files

Within each component, consistent file naming makes code navigation predictable:

```
component/
├── main.tf              # Main resources and data sources
├── variables.tf         # Input variables
├── outputs.tf           # Output variables
├── README.md            # Setup instructions
├── dependencies.tf      # (Optional) External data sources
├── providers.tf         # (Optional) Provider configuration
└── terraform.tfstate    # Local state (usually .gitignored)
```

#### Standard Files Explained

**`main.tf`**
- Contains the actual AWS resources being created
- Where the bulk of infrastructure code lives
- Can be split into `main-iam.tf`, `main-rds.tf`, etc. if it gets too long

**`variables.tf`**
- Declares all input variables for this module
- Includes descriptions, types, defaults, and validation
- Think of this as the "interface" to your Terraform code

**`outputs.tf`**
- Declares all output values exposed by this module
- These can be referenced by other modules via `terraform_remote_state`
- Useful for sharing resource IDs, endpoints, etc.

**`dependencies.tf`** (optional)
- Groups all `data` sources that fetch external information
- Makes it clear what external things this module depends on
- Easier to see required permissions and assumptions

**`providers.tf`** (optional)
- Centralizes all `provider` blocks and authentication
- Makes it obvious which cloud providers you're using
- Useful when using multiple providers or regions

## Physical Isolation via Directory Structure: How It Works

Understanding HOW file layout achieves isolation is critical for appreciating why it's superior to workspaces for production infrastructure.

### Concept

File layout provides **physical isolation** by using **separate directory structures and separate Terraform configurations** for each environment. Each environment is completely independent, with no shared code or shared state.

### Mechanism: Physical Separation

```bash
# Navigate to a specific environment
cd stage/services/webserver-cluster

# This is a SEPARATE Terraform configuration
terraform init
terraform apply
  → Uses: stage/services/webserver-cluster/main.tf
  → State file: S3 key = stage/services/webserver-cluster/terraform.tfstate
  → Affects ONLY staging web servers

# To switch environments, physically navigate to a different folder
cd ../../../prod/services/webserver-cluster

# This is a COMPLETELY DIFFERENT configuration
terraform init
terraform apply
  → Uses: prod/services/webserver-cluster/main.tf (different code!)
  → State file: S3 key = prod/services/webserver-cluster/terraform.tfstate
  → Affects ONLY production web servers
```

### Directory-Based Isolation

```
terraform/
├── stage/                    # Staging = Complete independence
│   ├── main.tf              # Different code
│   ├── variables.tf         # Different defaults (t3.micro)
│   ├── terraform.tfstate    # Different state
│   └── Backend config (can use different credentials)
│
└── prod/                     # Production = Complete independence
    ├── main.tf              # Different code
    ├── variables.tf         # Different defaults (t3.large)
    ├── terraform.tfstate    # Different state
    └── Backend config (can use different credentials)
```

### AWS Backend Behavior with File Layout

```
S3 Backend with separate state files:
s3://terraform-state/
├── stage/data-stores/mysql/terraform.tfstate
├── stage/services/webserver-cluster/terraform.tfstate
├── prod/data-stores/mysql/terraform.tfstate
└── prod/services/webserver-cluster/terraform.tfstate

Each folder has EXPLICIT configuration:

# stage/services/webserver-cluster/terraform.tf
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "stage/services/webserver-cluster/terraform.tfstate"  ← EXPLICIT
    region = "us-east-2"
  }
}

# prod/services/webserver-cluster/terraform.tf
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "prod/services/webserver-cluster/terraform.tfstate"   ← EXPLICIT
    region = "us-east-2"
  }
}

🔑 Key Points:
  - Backend path is EXPLICIT (not magic paths)
  - Can use DIFFERENT credentials per environment
  - Can use DIFFERENT buckets per environment
  - DynamoDB locks can be independent
  - RBAC/IAM can be enforced per environment
```

### RBAC/IAM Separation (Physical Isolation Advantage)

File layout enables **environment-specific access control**:

```json
// Developer IAM Policy - Can only access staging
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::terraform-state/stage/*"
}

// DevOps IAM Policy - Can access production
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::terraform-state/prod/*"
}
```

**Workspaces can't do this** because all workspaces use the same S3 path prefix (`env:/`).

### Visibility and Safety

File layout provides **physical visibility** of environment:

```bash
# In file layout, environment is OBVIOUS
$ pwd
/infrastructure/prod/services/webserver-cluster
$ terraform destroy
# ✅ SAFE: Folder path shows this is production

# In workspaces, environment is INVISIBLE
$ pwd
/workspaces-example/one-instance           # No indication of environment!
$ terraform destroy
# ❌ DANGEROUS: Could be any workspace!
```

### Configuration Difference Example

```hcl
# stage/services/webserver/variables.tf (Cost-optimized)
variable "instance_type" {
  default = "t3.micro"     # Small and cheap
}
variable "min_capacity" {
  default = 1              # Single instance for testing
}

# prod/services/webserver/variables.tf (Production-grade)
variable "instance_type" {
  default = "t3.xlarge"    # Large for load
}
variable "min_capacity" {
  default = 3              # Multiple instances for HA
}
```

With file layout, these are **completely separate files** in different folders. With workspaces, they'd be conditional logic in a single file (ugly and error-prone).

### Advantages of Physical Isolation

- ✅ **Crystal clear visibility**: Folder path shows exactly which environment you're modifying
- ✅ **RBAC/IAM separation**: Different teams can have different permissions per environment
- ✅ **Security compartmentalization**: Compromised staging credentials don't expose production
- ✅ **Version control clarity**: Git diff shows exactly which environment changed
- ✅ **Mistake prevention**: Must physically navigate to prod folder to affect production
- ✅ **Code review enforcement**: Can require approval before prod folder changes
- ✅ **Compliance friendly**: Audit logs clearly show which environment was modified when
- ✅ **Independent backends**: Can use different backend solutions per environment
- ✅ **State corruption isolation**: One environment's state issues don't affect others
- ✅ **Clean code**: No conditional logic scattered throughout (`if workspace == "prod" then ...`)

### Disadvantages of Physical Isolation

- ❌ **Code duplication**: Stage and prod have similar code (mitigated with modules)
- ❌ **Cross-environment dependencies**: Need `terraform_remote_state` to reference other environments
- ❌ **More boilerplate**: Multiple folders vs single main.tf
- ❌ **More complex workflows**: Multiple `terraform init` and `cd` commands
- ❌ **Learning curve**: Must understand folder navigation and state file organization

### Real-World Safety Example

```bash
# Production infrastructure with file layout
$ pwd
/infrastructure/prod/services/webserver-cluster

# Making critical changes
$ terraform destroy

# ✅ MULTIPLE PROTECTIONS TRIGGERED:
# 1. pwd shows "/prod/" (crystal clear visibility)
# 2. Code review required (infrastructure-as-code practice)
# 3. Different IAM credentials needed (enforced by CI/CD)
# 4. Separate state file (can't affect staging)
# 5. Full audit trail in git history
# 6. Can add require-approval workflow for prod folder
```

---

## How to Use This Structure

### 1. Understand Isolation

Each folder is **completely independent**:

```bash
# These operations are isolated - they don't affect each other
cd stage/data-stores/mysql && terraform apply    # Only affects MySQL in staging
cd stage/services/webserver-cluster && terraform apply  # Only affects web servers in staging
cd global/s3 && terraform apply                  # Only affects shared state infrastructure
```

This isolation is the **primary advantage** over workspaces.

### 2. Backend Configuration

Each component has its own state file path:

```hcl
# global/s3/main.tf
backend "s3" {
  key = "global/s3/terraform.tfstate"
}

# stage/data-stores/mysql/main.tf
backend "s3" {
  key = "stage/data-stores/mysql/terraform.tfstate"
}

# stage/services/webserver-cluster/main.tf
backend "s3" {
  key = "stage/services/webserver-cluster/terraform.tfstate"
}
```

The state file path mirrors your folder structure, making the connection obvious.

### 3. Working with Dependencies

When one component depends on another (e.g., web server needs database endpoint), use `terraform_remote_state`:

```hcl
# stage/services/webserver-cluster/main.tf

# Read the MySQL output from its remote state
data "terraform_remote_state" "mysql" {
  backend = "s3"
  config = {
    bucket = "terraform-smyha"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-2"
  }
}

# Use the database endpoint in your web server config
resource "aws_instance" "web" {
  # ... other config ...
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_endpoint = data.terraform_remote_state.mysql.outputs.database_endpoint
  }))
}
```

## Advantages of File Layout

### 1. Clear Code Organization

The folder structure mirrors your infrastructure organization:

```
Looking at the directories, you immediately understand:
- What environments exist (stage, prod)
- What components are in each environment
- Where specific resources are defined
```

### 2. Safety and Isolation

Each component is completely isolated:

```bash
# This is safe - even if something goes wrong, it's isolated to one component
cd stage/services/webserver-cluster && terraform destroy

# This doesn't affect production
# This doesn't affect the MySQL database
# Only web servers in staging are destroyed
```

Compare to workspaces where a single mistake can destroy the wrong environment.

### 3. Team Collaboration

Multiple team members can work safely on different environments:

```bash
# Developer 1 - Working on staging database
cd stage/data-stores/mysql && terraform plan

# Developer 2 - Working on staging web servers (no conflicts!)
cd stage/services/webserver-cluster && terraform plan

# DevOps - Working on production (safe from above changes)
cd prod/services/webserver-cluster && terraform plan
```

Different developers, different components, no conflicts.

### 4. Environment-Specific Configuration

Each environment can be tuned independently:

```hcl
# stage/services/webserver-cluster/variables.tf
variable "instance_type" {
  default = "t3.micro"  # Cost-effective for testing
}

# prod/services/webserver-cluster/variables.tf
variable "instance_type" {
  default = "t3.large"  # Powerful for production
}
```

### 5. Access Control

Different teams can have different permissions:

```
AWS IAM Policy:
- Dev team:   Can access stage/* but not prod/*
- Ops team:   Can access prod/* and global/*
- DBA team:   Can access */data-stores/* but not services/*
```

This is impossible with workspaces (same backend = same credentials).

## Disadvantages of File Layout

### 1. Multiple Commands Required

You can't create an entire environment with one command:

```bash
# With file layout, you need to run apply in each component
cd global/s3 && terraform apply
cd stage/data-stores/mysql && terraform apply
cd stage/services/webserver-cluster && terraform apply
cd prod/data-stores/mysql && terraform apply
cd prod/services/webserver-cluster && terraform apply

# Compare to one environment with Terragrunt (Chapter 10):
terragrunt run-all apply
```

**Solution**: Use Terragrunt for automated multi-folder deployment.

### 2. Code Duplication

You'll have similar code in stage and prod:

```
stage/services/webserver-cluster/main.tf
prod/services/webserver-cluster/main.tf
```

Both files look almost identical (just different variable values).

**Solution**: Use Terraform modules (Chapter 4) to keep code DRY.

### 3. Resource Dependencies are Complex

If web servers depend on a database, you can't use simple references:

```hcl
# This WON'T work (different folders):
resource "aws_instance" "web" {
  user_data = "mysql endpoint: ${aws_db_instance.mysql.endpoint}"
  #                            ^^^^ Can't reference different folder!
}
```

Instead, you must use `terraform_remote_state` which is more verbose:

```hcl
# This WORKS but is more complex:
data "terraform_remote_state" "mysql" {
  backend = "s3"
  config = {
    bucket = "terraform-smyha"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-2"
  }
}

resource "aws_instance" "web" {
  user_data = "mysql endpoint: ${data.terraform_remote_state.mysql.outputs.endpoint}"
}
```

**Solution**: Use dependency blocks in Terragrunt (Chapter 10) for cleaner syntax.

## Comparison: Workspaces vs. File Layout

| Feature | Workspaces | File Layout |
|---------|-----------|------------|
| **State Isolation** | Same backend, different files | Separate backends or keys |
| **Access Control** | Shared credentials for all | Different credentials per env |
| **Code Visibility** | Hidden in workspaces | Clear folder structure |
| **Safety** | High risk of mistakes | Low risk, isolated |
| **Suitable for Prod** | ❌ No | ✅ Yes |
| **Easy to Deploy** | ✅ One command | ❌ Multiple commands |
| **Learning Curve** | ✅ Easy | Moderate |
| **Team Scaling** | ❌ Difficult | ✅ Good |

## Best Practices

### 1. Organize by Environment First

```
Good:
- stage/  → All staging infrastructure together
- prod/   → All production infrastructure together

Bad:
- component-a/stage/  → Scattered organization
- component-a/prod/
- component-b/stage/
```

### 2. Keep Components Focused

```
Good:
- stage/services/webserver-cluster/  → Single responsibility
- stage/data-stores/mysql/

Bad:
- stage/services/everything/  → Too many resources in one folder
```

### 3. Use Consistent Naming

```
Good:
- main.tf
- variables.tf
- outputs.tf
- dependencies.tf
- providers.tf

Bad:
- app.tf
- vars.tf
- config.tf
- random_file.tf  → Inconsistent naming
```

### 4. Document Folder Purpose

Each folder should have a README explaining:

```markdown
# Stage MySQL

This module creates a MySQL RDS instance for the staging environment.

## Resources

- AWS RDS MySQL instance (db.t3.micro)
- Security group for database access
- Parameter group for configuration

## Dependencies

- VPC from stage/vpc module

## Outputs

- `database_endpoint` - Connection string for applications
- `database_port` - Database port (3306)
```

### 5. Use terraform_remote_state for Dependencies

```hcl
# Proper way to reference other components
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "terraform-smyha"
    key    = "stage/vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

# Now reference its outputs
resource "aws_instance" "web" {
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_id
}
```

## File Layout Workflow Example

### Step 1: Deploy Shared Infrastructure

```bash
cd global/s3
terraform init -backend-config=../backend.hcl
terraform plan
terraform apply
```

### Step 2: Deploy Staging Environment

```bash
# Create VPC first (usually required)
cd stage/vpc
terraform init -backend-config=../../backend.hcl
terraform apply

# Then databases
cd stage/data-stores/mysql
terraform init -backend-config=../../backend.hcl
terraform apply

# Finally applications
cd stage/services/webserver-cluster
terraform init -backend-config=../../backend.hcl
terraform apply
```

### Step 3: Deploy Production Environment

Repeat the same process for `prod/`:

```bash
cd prod/vpc && terraform apply
cd prod/data-stores/mysql && terraform apply
cd prod/services/webserver-cluster && terraform apply
```

### Step 4: Update All Environments

When you want to update all environments:

```bash
# Stage
cd stage/services/webserver-cluster && terraform apply

# Prod (independently, controlled, reviewed)
cd prod/services/webserver-cluster && terraform apply -var-file="prod.tfvars"
```

## Migration from Workspaces

If you're currently using workspaces, migrate to file layout:

```bash
# Old workspace approach
terraform workspace select staging
terraform apply

# New file layout approach
cd stage/services/webserver-cluster
terraform apply
```

Benefits of migration:
- ✅ Safer (no more workspace confusion)
- ✅ Clearer code organization
- ✅ Better team collaboration
- ✅ Production-ready isolation

## Next Steps: Modules and Terragrunt

This file layout is powerful, but you can enhance it further:

1. **Terraform Modules (Chapter 4)** - Reduce duplication across stage/prod
2. **Terragrunt (Chapter 10)** - Run commands across multiple folders automatically

Example evolution:

```
# Stage 1: File Layout (current)
stage/services/webserver-cluster/  ← 200 lines of code
prod/services/webserver-cluster/   ← 180 lines of duplicate code

# Stage 2: Add Modules
modules/webserver-cluster/         ← 150 lines of reusable code
stage/services/webserver-cluster/  ← 30 lines calling module
prod/services/webserver-cluster/   ← 30 lines calling module

# Stage 3: Add Terragrunt
terragrunt.hcl                     ← 20 lines of config
terragrunt run-all apply           ← Single command deploys everything
```

## Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/configuration.html)
- [terraform_remote_state Data Source](https://www.terraform.io/docs/language/state/remote-state-data.html)
- [Terraform Modules](https://www.terraform.io/docs/language/modules/develop/)
- [Terragrunt](https://terragrunt.gruntwork.io/) - For automating file layout deployments
