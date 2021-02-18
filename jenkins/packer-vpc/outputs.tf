output "vpc_id" {
  value = aws_vpc.default.id
}

output "subnet_id" {
  value = aws_subnet.zone-a.id
}

output "security_group_id" {
  value = aws_security_group.default.id
}

