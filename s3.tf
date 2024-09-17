resource "aws_s3_bucket" "s3_bucket" {
  bucket_prefix = "fortigate-bucket-"
  tags          = merge(local.common_tags, { Name = "fortigate-bucket-${var.vpc_name}" })
}

resource "aws_s3_object" "fortigate_license" {
  count  = var.license_type == "byol" ? length(var.fortigate_license) : 0
  bucket = aws_s3_bucket.s3_bucket.bucket
  key    = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}.lic"
  source = var.fortigate_license[count.index]
  etag   = filemd5(var.fortigate_license[count.index])
}

resource "aws_s3_object" "fortigate_config" {
  count        = length(var.fortigate)
  key          = "${var.fortigate[count.index].hostname_prefix}-${element(data.aws_availability_zones.available.names, count.index)}.conf"
  bucket       = aws_s3_bucket.s3_bucket.id
  content      = local.fortigate_content[count.index]
  etag         = md5(local.fortigate_content[count.index])
  content_type = "text/*"
}

resource "aws_vpc_endpoint" "s3-endpoint-fortigate" {
  vpc_id          = aws_vpc.security-vpc.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.external_route_table.id]
  policy          = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
  tags = {
    Name = "s3-endpoint-fgtvm-vpc"
  }
  lifecycle {
    ignore_changes = [
      policy
    ]
  }
}
