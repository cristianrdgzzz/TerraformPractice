# S3 Backend Setup Guide

This document explains how to set up and use the S3 backend for this Terraform project using partial configurations to reduce duplication.

## Quick Overview

This project uses a **partial backend configuration** approach:

- **Shared settings** (bucket name, region, DynamoDB table) → `backend.hcl` (root)
- **Module-specific settings** (state file path) → `backend "s3" { key = "..." }` in each module's `main.tf`

This reduces copy-paste duplication while maintaining unique state files for each module.

## Project Structure

```
file-layout-example/
├── backend.hcl                              # Shared backend configuration
├── BACKEND_SETUP.md                         # This file
├── global/
│   └── s3/
│       └── main.tf                          # Partial backend config (key only)
└── stage/
    ├── data-stores/
    │   └── mysql/
    │       ├── main.tf                      # Add partial backend config here
    │       └── backend-config-example.hcl   # Example for reference
    └── services/
        └── webserver-cluster/
            ├── main.tf                      # Add partial backend config here
            └── backend-config-example.hcl   # Example for reference
```

## Step 1: Create S3 Bucket and DynamoDB Table

First, you need to create the actual S3 bucket and DynamoDB table for state storage.

Navigate to the global/s3 module and deploy it WITHOUT the backend (local state first):

```bash
cd global/s3
terraform init -backend=false
terraform apply -var="bucket_name=terraform-state-12345" -var="table_name=terraform-locks"
```

This creates the S3 bucket and DynamoDB table in AWS.

## Step 2: Review backend.hcl

Check the `backend.hcl` file in the root directory:

```hcl
bucket         = "terraform-up-and-running-state"
region         = "us-east-2"
dynamodb_table = "terraform-up-and-running-locks"
encrypt        = true
```

Update these values if your S3 bucket or DynamoDB table have different names.

## Step 3: Configure Backend for global/s3 Module

The global/s3 module already has a partial backend configuration. To migrate to S3:

```bash
cd global/s3

# Initialize with partial backend configuration
terraform init -backend-config=../backend.hcl

# When prompted, answer "yes" to copy existing state to S3
```

After initialization, your state will be stored in S3 at `global/s3/terraform.tfstate`.

## Step 4: Configure Backend for Other Modules

For `stage/data-stores/mysql` module:

1. Open `stage/data-stores/mysql/main.tf`
2. Add this partial backend configuration in the `terraform` block:

```hcl
terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # Partial backend configuration
  backend "s3" {
    key = "stage/data-stores/mysql/terraform.tfstate"
  }
}
```

3. Initialize with the shared backend configuration:

```bash
cd stage/data-stores/mysql
terraform init -backend-config=../../backend.hcl
```

Repeat the same process for `stage/services/webserver-cluster`:

1. Add to `stage/services/webserver-cluster/main.tf`:

```hcl
backend "s3" {
  key = "stage/services/webserver-cluster/terraform.tfstate"
}
```

2. Initialize:

```bash
cd stage/services/webserver-cluster
terraform init -backend-config=../../backend.hcl
```

## Understanding the Approach

### What's in backend.hcl (Shared)

```hcl
bucket         = "terraform-up-and-running-state"
region         = "us-east-2"
dynamodb_table = "terraform-up-and-running-locks"
encrypt        = true
```

These settings are the same for all modules and defined once.

### What's in Each Module's main.tf (Unique)

```hcl
backend "s3" {
  key = "stage/data-stores/mysql/terraform.tfstate"
}
```

Each module has a unique key to store its state in a separate location.

### Why This Approach?

✓ **Reduces duplication**: Don't repeat bucket name in every module
✓ **Easy to change**: Update backend settings in one place
✓ **Maintains separation**: Each module has its own state file
✓ **Scalable**: Works well for projects with many modules
✓ **DRY principle**: Don't Repeat Yourself

## Initialization Command Reference

### Global/S3 Module (Root level)
```bash
cd global/s3
terraform init -backend-config=../backend.hcl
```

### Stage/Data-Stores/MySQL Module (Two levels deep)
```bash
cd stage/data-stores/mysql
terraform init -backend-config=../../backend.hcl
```

### Stage/Services/Webserver-Cluster Module (Two levels deep)
```bash
cd stage/services/webserver-cluster
terraform init -backend-config=../../backend.hcl
```

## Troubleshooting

### Issue: "Backend initialization failed"

**Solution**: Verify the path to `backend.hcl` is correct:
- From `global/s3/`: use `../backend.hcl`
- From `stage/data-stores/mysql/`: use `../../backend.hcl`
- From `stage/services/webserver-cluster/`: use `../../backend.hcl`

### Issue: "AccessDenied" accessing S3

**Solution**: Ensure your AWS credentials have permissions for S3 and DynamoDB:

```bash
aws sts get-caller-identity
aws s3 ls s3://terraform-up-and-running-state/
aws dynamodb list-tables --region us-east-2
```

### Issue: "Error acquiring state lock"

**Solution**: Another Terraform operation might be running. Wait or force unlock:

```bash
terraform force-unlock <LOCK_ID>
```

## What Happens During terraform init

When you run `terraform init -backend-config=../backend.hcl`:

1. Terraform reads the partial backend configuration from your `main.tf`
2. Terraform merges it with the settings from `backend.hcl`
3. The complete configuration is:
   ```
   bucket         = "terraform-up-and-running-state"
   region         = "us-east-2"
   dynamodb_table = "terraform-up-and-running-locks"
   encrypt        = true
   key            = "stage/data-stores/mysql/terraform.tfstate"
   ```
4. Terraform initializes and configures the S3 backend

## Next Steps

Once all modules are configured with the S3 backend:

1. **Verify state files are in S3**:
   ```bash
   aws s3 ls s3://terraform-up-and-running-state/
   ```

2. **Check state locking works**:
   ```bash
   aws dynamodb scan --table-name terraform-up-and-running-locks
   ```

3. **Run Terraform operations**:
   ```bash
   terraform plan
   terraform apply
   ```

You should see "Acquiring state lock" and "Releasing state lock" messages confirming the locking mechanism is working.

## Changing Backend Settings

If you need to change the S3 bucket name or region:

1. Edit `backend.hcl`
2. Run `terraform init -backend-config=../backend.hcl` in each module
3. Answer "yes" when asked to reconfigure the backend

That's it! All modules will now use the new backend configuration.

## Additional Resources

For more information on partial backend configurations, see:
- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/configuration.html)
- Main README.md in this directory for complete S3 backend documentation
