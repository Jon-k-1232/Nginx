# VPC Data Source - Reference to existing VPC
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Default Security Group - to be imported
# This resource represents the default security group created with the VPC
resource "aws_default_security_group" "default" {
  vpc_id = var.vpc_id

  # Default rules - adjust after import based on actual AWS configuration
  ingress {
    protocol  = "-1"
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-default-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Main Route Table - to be imported
# This is the main route table associated with the VPC
resource "aws_default_route_table" "main" {
  default_route_table_id = data.aws_vpc.main.main_route_table_id

  # Routes will be configured after import based on actual AWS state
  # Local route is implicit and doesn't need to be defined

  tags = {
    Name        = "${local.name_prefix}-main-rt"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Default Network ACL - to be imported
# This is the default NACL created with the VPC
# Note: The default NACL ID must be provided as a variable since it's not 
# exposed by the VPC data source
resource "aws_default_network_acl" "default" {
  default_network_acl_id = var.default_nacl_id

  # Default allow all inbound rule
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Default allow all outbound rule
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${local.name_prefix}-default-nacl"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
