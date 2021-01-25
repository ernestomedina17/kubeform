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

# https://aws.amazon.com/premiumsupport/knowledge-center/cloudfront-https-requests-s3/ 
resource "aws_s3_bucket" "b" {
  bucket = local.s3_origin_id
  acl    = "private"

  tags = {
    Name = "terraform"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.s3_origin_id}logs"
  acl    = "log-delivery-write"  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html#AccessLogsBucketAndFileOwnership

  tags = {
    Name = "terraform"
  }
}

locals {
  s3_origin_id = "mariannmirandawebsite"
}

resource "aws_s3_bucket_object" "index" {
  bucket = aws_s3_bucket.b.bucket
  key    = "index.html"
  source = "index.html"
  etag = filemd5("index.html")
  content_type = "text/html"
}
 
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "Website blog"
}
 
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Welcome to my blog"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_domain_name 
    prefix          = "blog"
  }

  aliases = ["mariannmiranda.com", "www.mariannmiranda.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    # viewer_protocol_policy = "allow-all"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600   # 1 hour
    max_ttl                = 86400  # 1 day
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400     # 1 day
    max_ttl                = 31536000  # 1 year
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600   # 1 hour
    max_ttl                = 86400  # 1 day
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"  # https://aws.amazon.com/cloudfront/pricing/

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "DE", "MX"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    minimum_protocol_version = "TLSv1.2_2019"  # https://www.globalsign.com/en/blog/ssl-vs-tls-difference
    acm_certificate_arn = "arn:aws:acm:us-east-1:055317306440:certificate/18fcb55e-733b-48a0-846f-95ad44ad24f0"
    ssl_support_method = "sni-only"
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
    evaluate_target_health  = false
    name                    = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                 = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "www.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    evaluate_target_health = true
    name                    = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                 = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
  }
}
 

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "readonly" {
  bucket = aws_s3_bucket.b.id
  policy = data.aws_iam_policy_document.s3_policy.json
}


data "aws_iam_policy_document" "s3_policy_log" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:PutBucketAcl"]
    resources = ["${aws_s3_bucket.logs.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "readwrite" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.s3_policy_log.json
}


