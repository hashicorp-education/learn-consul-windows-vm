resource "random_string" "random" {
  length  = 4
  special = false
}

locals {
  name   = "${var.name_prefix}-${random_string.random.id}"
  hvn_id = "${local.name}-hvn"
}

data "aws_availability_zones" "available" {
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  azs                  = data.aws_availability_zones.available.names
  cidr                 = "10.0.0.0/16"
  enable_dns_hostnames = true
  name                 = "${local.name}-vpc"
  private_subnets      = []
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

resource "hcp_hvn" "main" {
  hvn_id         = local.hvn_id
  cloud_provider = "aws"
  region         = var.hvn_region
  cidr_block     = "172.25.32.0/20"
}

module "aws_hcp_consul" {
  source  = "hashicorp/hcp-consul/aws"
  version = "~> 0.8.8"

  hvn             = hcp_hvn.main
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  route_table_ids = module.vpc.public_route_table_ids
}

resource "hcp_consul_cluster" "main" {
  cluster_id      = local.name
  hvn_id          = hcp_hvn.main.hvn_id
  public_endpoint = true
  tier            = "development"
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}