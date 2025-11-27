# Nginx

## Overview

This repository contains the Nginx infrastructure configuration for AWS ECS deployment.

## Terraform Configuration

The `terraform/` directory contains Terraform configurations for:
- ECS Task Definition and Service for Nginx
- CloudWatch Log Groups and Alarms
- VPC resource management (security groups, route tables, NACLs)

### Importing Existing VPC Resources

The VPC resources (security groups, route tables, NACLs) can be imported into Terraform state to manage them alongside other infrastructure.

#### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform 1.5+ installed
3. Access to the target VPC (`vpc-04f4c4cf527f99b9a`)

#### Get Resource IDs from AWS

Before importing, retrieve the resource IDs from AWS:

```bash
# Get the default security group ID
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-04f4c4cf527f99b9a" "Name=group-name,Values=default" \
  --region us-west-2 \
  --query 'SecurityGroups[0].GroupId' \
  --output text

# Get the main route table ID
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-04f4c4cf527f99b9a" "Name=association.main,Values=true" \
  --region us-west-2 \
  --query 'RouteTables[0].RouteTableId' \
  --output text

# Get the default network ACL ID
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=vpc-04f4c4cf527f99b9a" "Name=default,Values=true" \
  --region us-west-2 \
  --query 'NetworkAcls[0].NetworkAclId' \
  --output text
```

#### Set Variables for Import

Set the resource IDs in your Terraform Cloud workspace or create a `terraform.tfvars` file:

```hcl
default_security_group_id = "sg-xxxxxxxxx"
main_route_table_id       = "rtb-xxxxxxxxx"
default_nacl_id           = "acl-xxxxxxxxx"
```

#### Run Import

```bash
cd terraform/
terraform init
terraform plan    # Review the import plan
terraform apply   # Execute the imports
```

The import blocks in `imports.tf` will automatically import the existing AWS resources into Terraform state without making any changes to AWS.

### Important Notes

- The import process is non-destructive - it only adds resources to Terraform state
- After import, run `terraform plan` to verify the configuration matches AWS
- Adjust the resource configurations in `vpc.tf` if there are differences between Terraform and AWS
