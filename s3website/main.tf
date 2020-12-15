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

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "documents/"
    }
}]
EOF
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
    name                   = aws_s3_bucket.website.dns_name
    zone_id                = aws_s3_bucket.website.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "www.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    name                   = aws_route53_record.main.name
    zone_id                = aws_s3_bucket.website.zone_id
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


