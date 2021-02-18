output "aws_ami" {
  value = data.aws_ami.jenkins.id
}

output "jenkins_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_fqdn" {
  value = "http://${aws_route53_record.jenkins.name}:8080"
}

