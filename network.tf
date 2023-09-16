resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet_1" {
  count = 2
  vpc_id = aws_vpc.example_vpc.id
  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_1" {
  count = 2
  vpc_id = aws_vpc.example_vpc.id
  cidr_block = "10.0.${count.index + 2}.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
}

resource "aws_route_table_association" "public_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet_1[count.index].id
  route_table_id = aws_vpc.example_vpc.default_route_table_id
}

resource "aws_route" "public_route" {
  count             = 2
  route_table_id    = aws_vpc.example_vpc.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id        = aws_internet_gateway.example_igw.id
}

resource "aws_security_group" "test-group" {
  name = "teste-group"
  description = "Allow all inboud and outbound traffic"
  vpc_id = aws_vpc.example_vpc.id

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
}