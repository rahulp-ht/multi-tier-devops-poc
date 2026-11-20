resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id     = aws_eip.nat.id
  connectivity_type = "public"
  subnet_id = one([
    for subnet in aws_subnet.public : subnet.id
    if subnet.availability_zone == "ap-south-1a"
  ])

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-ap-south-1a"
  })
}

resource "aws_route" "private_ipv4_egress" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}
