# ===========================================================================
# VPC and networking
#
# Layout (per AZ): one public subnet (ALB + NAT) and one private subnet
# (Fargate tasks). Public subnets route to the internet via an Internet
# Gateway; private subnets reach the internet OUTBOUND ONLY via a NAT Gateway
# in their own AZ.
# ===========================================================================

# Discover usable Availability Zones in the current region, instead of
# hardcoding names like "us-west-2a" (which vary by account/region).
data "aws_availability_zones" "available" {
  state = "available"
}

# ---- The VPC itself ----
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # DNS settings required so resources can resolve names and reach AWS service
  # endpoints (ECR, CloudWatch, etc.) by hostname.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

# ---- Internet Gateway: the VPC's single door to the public internet ----
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-igw" }
}

# ---- Public subnets (one per AZ) ----
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # resources launched here get a public IP

  tags = { Name = "${var.name}-public-${count.index + 1}" }
}

# ---- Private subnets (one per AZ) ----
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  # No public IP: tasks here are not directly reachable from the internet.

  tags = { Name = "${var.name}-private-${count.index + 1}" }
}

# ---- Elastic IPs for the NAT Gateways (one per AZ) ----
# A NAT Gateway needs a fixed public IP to use as its outbound address.
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip-${count.index + 1}" }
}

# ---- NAT Gateways (one per AZ, sitting in the public subnets) ----
# This is the costed resource. One per AZ = full HA (each private subnet uses
# the NAT in its own AZ, so a single AZ failure can't take out the other's
# outbound connectivity).
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags       = { Name = "${var.name}-nat-${count.index + 1}" }
  depends_on = [aws_internet_gateway.main] # NAT needs the IGW to reach the internet
}

# ---- Public route table: send all internet-bound traffic to the IGW ----
# One shared table is fine for public subnets — they all egress the same way.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---- Private route tables: ONE PER AZ, each egressing via its own AZ's NAT ----
# Per-AZ tables are what make one-NAT-per-AZ genuinely highly available.
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${var.name}-private-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
