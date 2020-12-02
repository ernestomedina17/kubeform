output "address_app1" {
  value = aws_elb.app1-elb.dns_name
}

output "address_app2" {
  value = aws_elb.app2-elb.dns_name
}
