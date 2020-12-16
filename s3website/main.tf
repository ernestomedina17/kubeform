terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  # access_key = "export AWS_ACCESS_KEY_ID='' in .bashrc"
  # secret_key = "export AWS_SECRET_ACCESS_KEY='' in .bashrc"
}

resource "aws_s3_bucket" "website" {
  bucket = "mariannmiranda.com"
  acl    = "public-read"
  policy = file("policy.json")

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket_object" "index" {
  bucket = aws_s3_bucket.website.bucket
  key    = "index.html"
  source = "index.html"
  etag = filemd5("index.html")
  content_type = "text/html"
}

resource "aws_s3_bucket" "www" {
  bucket = "www.mariannmiranda.com"
  acl    = "public-read"
  policy = file("policy-www.json")

  website {
    redirect_all_requests_to = aws_s3_bucket.website.bucket
  }
}

data "aws_route53_zone" "mariannmiranda-com" {
  name         = "mariannmiranda.com."
  private_zone = false
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = data.aws_route53_zone.mariannmiranda-com.name
  type    = "A"

  alias {
    name                   = aws_s3_bucket.website.website_domain
    zone_id                = aws_s3_bucket.website.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "www.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    name                   = aws_s3_bucket.www.website_domain
    zone_id                = aws_s3_bucket.www.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "default" {
  name = "mariannmiranda.com"

  vpc {
    vpc_id = aws_vpc.default.id
  }
}

# Default VPC
resource "aws_vpc" "default" {
  cidr_block = "153.2.0.0/16"
}

