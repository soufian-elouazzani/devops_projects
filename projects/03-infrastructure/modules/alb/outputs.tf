output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "blue_target_group_arn" {
  value = aws_lb_target_group.color["blue"].arn
}

output "green_target_group_arn" {
  value = aws_lb_target_group.color["green"].arn
}
