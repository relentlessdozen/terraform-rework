output "alb_dns_name" {
  value       = aws_lb.dev-lb.dns_name
  description = "The dns for load balance"
}

output "asg_name" {
  value       = aws_autoscaling_group.example.name
  description = "The name of the Auto Scaling Group"
}

output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}

## Allow the configuration of custom ingress and egress rules  by exporting the SG ID ##
output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "The ID of the Security Group attached to the load balancer"
}
