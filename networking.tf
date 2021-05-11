data "aws_availability_zones" "available" {
  state = "available"
}

locals {

  // https://www.davidc.net/sites/default/subnets/subnets.html?network=10.0.0.0&mask=16&division=11.721
  subnets = cidrsubnets(var.cidr_block, 3, 3, 3, 3, 2, 2)
  subnets_public = {
    for key, value in [local.subnets[0],local.subnets[1]] :
    data.aws_availability_zones.available.zone_ids[key] => {
      availability_zone_id = data.aws_availability_zones.available.zone_ids[key]
      cidr_block           = value
    }
  }
  subnets_data = {
    for key, value in [local.subnets[2],local.subnets[3]] :
    data.aws_availability_zones.available.zone_ids[key] => {
      availability_zone_id = data.aws_availability_zones.available.zone_ids[key]
      cidr_block           = value
    }
  }
  subnets_app = {
    for key, value in [local.subnets[4],local.subnets[5]] :
    data.aws_availability_zones.available.zone_ids[key] => {
      availability_zone_id = data.aws_availability_zones.available.zone_ids[key]
      cidr_block           = value
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  tags = merge(local.mandatory_tags, {
    Name = local.naming_prefix
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.mandatory_tags, {
    Name = local.naming_prefix
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "${local.naming_prefix}-vpc-flow-logs"
  retention_in_days = var.environment == "dev" ? 7 : 90

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-vpc-flow-logs"
  })
}

resource "aws_subnet" "public" {

  for_each = local.subnets_public

  vpc_id     = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]

  availability_zone_id = each.value["availability_zone_id"]

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-public-${each.value["availability_zone_id"]}"
  })
}

resource "aws_subnet" "app" {

  for_each = local.subnets_app

  vpc_id     = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]

  availability_zone_id = each.value["availability_zone_id"]

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-app-${each.value["availability_zone_id"]}"
  })
}

resource "aws_subnet" "data" {

  for_each = local.subnets_data

  vpc_id     = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]

  availability_zone_id = each.value["availability_zone_id"]

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-data-${each.value["availability_zone_id"]}"
  })
}

// Internet Access

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.mandatory_tags, {
    Name = local.naming_prefix
  })
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.gw]

  for_each = aws_subnet.public

  tags = merge(local.mandatory_tags, {
    Name      = "${local.naming_prefix}-nat-${each.key}"
    NATSubnet = each.value.id
  })
}

resource "aws_nat_gateway" "gw" {
  depends_on = [aws_internet_gateway.gw]

  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-${each.key}"
  })
}

// Routing

resource "aws_route_table" "egress" {

  for_each = aws_subnet.public

  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-egress-${each.key}"
  })
}

resource "aws_route_table_association" "egress" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.egress[each.key].id
}


resource "aws_route_table" "app" {

  for_each = aws_subnet.app

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw[each.key].id
  }

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-egress-${each.key}"
  })
}

resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}