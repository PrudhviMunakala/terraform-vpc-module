resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = local.vpc_final_tags
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = local.igw_final_tags
}
# public subnet..
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr[count.index]
  availability_zone = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-public-${local.az_names[count.index]}"
    },
    var.public_subnet_tags
  )
}

# private subnet..
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-private-${local.az_names[count.index]}"
    },
    var.private_subnet_tags
  )
}

# database subnet..
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidr[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-database-${local.az_names[count.index]}"
    },
    var.database_subnet_tags
  )
}

# public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id


  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-public-rt"
    },
    var.public_rt_tags
  )
}

# private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id


  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-private-rt"
    },
    var.private_rt_tags
  )
}

# database route table
resource "aws_route_table" "database_rt" {
  vpc_id = aws_vpc.main.id


  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-database-rt"
    },
    var.database_rt_tags
  )
}

# route to public subnet
resource "aws_route" "public" {
  route_table_id            = aws_route_table.public_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_eip" "nat" {
  
  domain   = "vpc"

  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-nat"
    },
    var.eip_tags
  )
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge (
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}"
    },
    var.nat_gateway_tags
  )
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# route to private subnet
resource "aws_route" "private" {
  route_table_id            = aws_route_table.private_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}

# route to database subnet
resource "aws_route" "database" {
  route_table_id            = aws_route_table.database_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}

# public route table association
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# private route table association
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# database route table association
resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidr)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database_rt.id
}

resource "aws_route" "public_peering" {
  count = var.enable_peering == true ? 1 : 0
  route_table_id            = aws_route_table.public_rt.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.default[count.index].id
}

resource "aws_route" "private_peering" {
  count = var.enable_peering == true ? 1 : 0
  route_table_id            = aws_route_table.private_rt.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.default[count.index].id
}

resource "aws_route" "database_peering" {
  count = var.enable_peering == true ? 1 : 0
  route_table_id            = aws_route_table.database_rt.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.default[count.index].id
}

resource "aws_route" "default_peering" {
  count = var.enable_peering == true ? 1 : 0
  route_table_id            = data.aws_route_table.default.id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.default[count.index].id
}



