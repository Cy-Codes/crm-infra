# ============================================================================
# AWS Network Foundation
# VPC with public subnets across availability zones plus the three security
# boundaries of the reference architecture: load balancer -> API -> database.
# ============================================================================

locals {
  any_ipv4_cidr       = "0.0.0.0/0"
  all_protocols       = "-1"
  subnet_newbits      = 8
  http_listener_port  = 80
  https_listener_port = 443
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, local.subnet_newbits, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.name_prefix}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = local.any_ipv4_cidr
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name_prefix}-public" }
}

resource "aws_route_table_association" "public" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "load_balancer" {
  name        = "${var.name_prefix}-alb"
  description = "Public HTTP/HTTPS ingress to the CRM API load balancers"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = local.http_listener_port
    to_port     = local.http_listener_port
    protocol    = "tcp"
    cidr_blocks = [local.any_ipv4_cidr]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = local.https_listener_port
    to_port     = local.https_listener_port
    protocol    = "tcp"
    cidr_blocks = [local.any_ipv4_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = local.all_protocols
    cidr_blocks = [local.any_ipv4_cidr]
  }
}

resource "aws_security_group" "api" {
  name        = "${var.name_prefix}-api"
  description = "CRM API tasks, reachable only from the load balancers"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "API traffic from the load balancers"
    from_port       = var.api_container_port
    to_port         = var.api_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = local.all_protocols
    cidr_blocks = [local.any_ipv4_cidr]
  }
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-db"
  description = "CRM databases, reachable from API tasks and the schema migrator CIDRs"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = toset(var.database_ports)
    content {
      description     = "Database port ${ingress.value}"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.api.id]
      cidr_blocks     = var.database_admin_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = local.all_protocols
    cidr_blocks = [local.any_ipv4_cidr]
  }
}
