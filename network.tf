resource "aws_vpc" "example_vpc" {
  count = var.vpc_cidr_block != null ? 1 : 0

  cidr_block = var.vpc_cidr_block

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnet_cidr_blocks)

  vpc_id                  = aws_vpc.example_vpc[0].id
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.example_vpc[0].id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_internet_gateway" "igw" {
  count  = length(var.public_subnet_cidr_blocks) > 0 ? 1 : 0
  vpc_id = aws_vpc.example_vpc[0].id

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_route_table_association" "public_association" {
  count = length(var.public_subnet_cidr_blocks)

  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_vpc.example_vpc[0].default_route_table_id
}

resource "aws_route" "public_route" {
  count                  = length(var.public_subnet_cidr_blocks) > 0 ? 1 : 0
  route_table_id         = aws_vpc.example_vpc[0].default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}

resource "aws_security_group" "ecs" {
  count = var.security_group_name != null ? 1 : 0

  name        = var.security_group_name
  description = "Allow all inboud and outbound traffic"
  vpc_id      = aws_vpc.example_vpc[0].id
  depends_on  = [aws_vpc.example_vpc]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
  lifecycle {
    ignore_changes = [tags]
  }
}
