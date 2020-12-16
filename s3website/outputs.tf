output "main_bucket_endpoint" {
  value = aws_s3_bucket.website.website_endpoint 
}

output "www_bucket_endpoint" {
  value = aws_s3_bucket.www.website_endpoint 
}

output "main_domain" {
  value = aws_route53_record.main.name
}

output "sub_domain" {
  value = aws_route53_record.www.name
}

