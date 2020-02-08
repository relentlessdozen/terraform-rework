output "alb_dns_name" {
  value       = aws_lb.dev-lb.dns_name
  description = "The dns for load balance"
}
