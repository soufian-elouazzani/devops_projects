data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  # A canary borrows weight from the active color. At 0 this is a hard cutover.
  blue_weight  = var.active_color == "blue" ? 100 - var.canary_weight : var.canary_weight
  green_weight = 100 - local.blue_weight

  blue_desired  = local.blue_weight > 0 ? var.desired_capacity : (var.warm_standby ? 1 : 0)
  green_desired = local.green_weight > 0 ? var.desired_capacity : (var.warm_standby ? 1 : 0)
}

module "network" {
  source = "./modules/network"

  name     = local.name
  vpc_cidr = var.vpc_cidr
  azs      = local.azs
}

module "security" {
  source = "./modules/security"

  name   = local.name
  vpc_id = module.network.vpc_id
}

module "alb" {
  source = "./modules/alb"

  name              = local.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  blue_weight       = local.blue_weight
  green_weight      = local.green_weight
}

module "compute" {
  source = "./modules/compute"

  name               = local.name
  instance_type      = var.instance_type
  private_subnet_ids = module.network.private_subnet_ids
  app_sg_id          = module.security.app_sg_id
  target_group_arns = {
    blue  = module.alb.blue_target_group_arn
    green = module.alb.green_target_group_arn
  }
  desired_capacity = {
    blue  = local.blue_desired
    green = local.green_desired
  }
  app_versions = {
    blue  = var.app_version_blue
    green = var.app_version_green
  }
}
