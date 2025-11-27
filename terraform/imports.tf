# Terraform Import Configuration
# 
# This file contains import blocks for bringing existing AWS VPC resources
# into Terraform state management.
#
# IMPORTANT: These import blocks will only work when running `terraform plan`
# or `terraform apply` with Terraform 1.5+. They will import the existing
# resources without making any changes to AWS.
#
# Usage:
#   1. Retrieve the resource IDs from AWS (see commands below)
#   2. Set the variables in your Terraform Cloud workspace or terraform.tfvars
#   3. Run `terraform init` to initialize the Terraform working directory
#   4. Run `terraform plan` to see the import plan
#   5. Run `terraform apply` to execute the imports
#
# After import, the resources will be managed by Terraform. Any configuration
# drift between the Terraform code and AWS will be shown in subsequent plans.
#
# ALTERNATIVE: You can also import manually using the Terraform CLI:
#   terraform import aws_default_security_group.default <security-group-id>
#   terraform import aws_default_route_table.main <route-table-id>
#   terraform import aws_default_network_acl.default <nacl-id>

# Import the default security group
# The security group ID can be found using:
# aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-04f4c4cf527f99b9a" "Name=group-name,Values=default" --region us-west-2 --query 'SecurityGroups[0].GroupId' --output text
import {
  to = aws_default_security_group.default
  id = var.default_security_group_id
}

# Import the default/main route table
# The route table ID can be found using:
# aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-04f4c4cf527f99b9a" "Name=association.main,Values=true" --region us-west-2 --query 'RouteTables[0].RouteTableId' --output text
import {
  to = aws_default_route_table.main
  id = var.main_route_table_id
}

# Import the default network ACL
# The NACL ID can be found using:
# aws ec2 describe-network-acls --filters "Name=vpc-id,Values=vpc-04f4c4cf527f99b9a" "Name=default,Values=true" --region us-west-2 --query 'NetworkAcls[0].NetworkAclId' --output text
import {
  to = aws_default_network_acl.default
  id = var.default_nacl_id
}
