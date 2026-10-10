output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = module.alb.alb_dns_name
}

output "blue_weight" {
  description = "Share of listener traffic forwarded to the blue target group."
  value       = local.blue_weight
}

output "green_weight" {
  description = "Share of listener traffic forwarded to the green target group."
  value       = local.green_weight
}

output "blue_desired_capacity" {
  value = local.blue_desired
}

output "green_desired_capacity" {
  value = local.green_desired
}

output "vpc_id" {
  value = module.network.vpc_id
}
