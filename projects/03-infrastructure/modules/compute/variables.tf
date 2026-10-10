variable "name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "target_group_arns" {
  type = map(string)
}

variable "desired_capacity" {
  type = map(number)
}

variable "app_versions" {
  type = map(string)
}
