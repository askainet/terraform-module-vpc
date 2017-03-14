resource "aws_vpc" "vpc" {
  cidr_block           = "${var.cidr}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support   = "${var.enable_dns_support}"
  tags                 = "${merge(var.tags, map("Name", format("%s", var.name)), map("VPC", var.name))}"
}

module "public_subnets" {
  source = "github.com/askainet/terraform-module-subnet-public?ref=v0.0.1"

  vpc_id                  = "${aws_vpc.vpc.id}"
  vpc_name                = "${var.name}"
  subnets                 = ["${var.public_subnets}"]
  azs                     = ["${var.azs}"]
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
  tags                    = "${merge(var.tags, map("VPC", var.name))}"
}

module "nat_gateways" {
  source = "github.com/askainet/terraform-module-nat-gateway?ref=v0.0.1"

  nat_gateway_count = "${(length(var.private_subnets) + length(var.database_subnets)) > 0 ? (var.nat_gateway_count < 0 ? length(var.public_subnets) : (var.nat_gateway_count > 0 ? var.nat_gateway_count : 0)) : 0}"
  public_subnets    = ["${module.public_subnets.subnet_ids}"]
}

module "private_subnets" {
  source = "github.com/askainet/terraform-module-subnet-private?ref=v0.0.2"

  vpc_id       = "${aws_vpc.vpc.id}"
  vpc_name     = "${var.name}"
  subnets      = ["${var.private_subnets}"]
  azs          = ["${var.azs}"]
  enable_nat   = "${var.nat_gateway_count != 0 ? true : false}"
  nat_gateways = "${module.nat_gateways.nat_gateway_ids}"
  tags         = "${merge(var.tags, map("VPC", var.name))}"
}

module "database_subnets" {
  source = "github.com/askainet/terraform-module-subnet-private?ref=v0.0.2"

  name         = "database"
  vpc_id       = "${aws_vpc.vpc.id}"
  vpc_name     = "${var.name}"
  subnets      = ["${var.database_subnets}"]
  azs          = ["${var.azs}"]
  enable_nat   = "${var.nat_gateway_count != 0 ? true : false}"
  nat_gateways = "${module.nat_gateways.nat_gateway_ids}"
  tags         = "${merge(var.tags, map("VPC", var.name))}"
}

resource "aws_db_subnet_group" "database" {
  count       = "${length(var.database_subnets) > 0 ? 1 : 0}"
  name        = "${var.name}-rds-subnet-group"
  description = "Database subnet group for VPC ${var.name}"
  subnet_ids  = ["${module.database_subnets.subnet_ids}"]
  tags        = "${merge(var.tags, map("Name", format("%s.rds-subnet-group", var.name)), map("VPC", var.name))}"
}
