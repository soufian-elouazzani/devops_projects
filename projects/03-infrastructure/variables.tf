variable "aws_region" {
  description = "Region for the lab stack."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Short name used in resource names. Keep it short: several AWS names cap at 32 characters."
  type        = string
  default     = "platform-lab"
}

variable "environment" {
  description = "Environment label stored in tags and names."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR for the lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "instance_type" {
  description = "Instance size for the application Auto Scaling Groups."
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Instance count for a color that is receiving traffic."
  type        = number
  default     = 1
}

variable "active_color" {
  description = "Color that receives the majority of traffic. The other color is the standby slot."
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_color)
    error_message = "active_color must be blue or green."
  }
}

variable "canary_weight" {
  description = "Percent of traffic sent to the inactive color. 0 is a blue-green cutover. 10 keeps a 10 percent canary on the inactive color."
  type        = number
  default     = 0

  validation {
    condition     = var.canary_weight >= 0 && var.canary_weight <= 50
    error_message = "canary_weight must be between 0 and 50 so the active color always keeps at least half of the traffic."
  }
}

variable "warm_standby" {
  description = "Keep one instance in the inactive color so a later weight change does not wait for scale-out."
  type        = bool
  default     = false
}

variable "app_version_blue" {
  description = "Version string baked into the blue launch template."
  type        = string
  default     = "1.0.0"
}

variable "app_version_green" {
  description = "Version string baked into the green launch template."
  type        = string
  default     = "1.0.0"
}
