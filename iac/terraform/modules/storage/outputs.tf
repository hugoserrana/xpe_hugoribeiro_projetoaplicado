output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "dashboard_bucket" {
  value = aws_s3_bucket.web.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.web.domain_name
}
