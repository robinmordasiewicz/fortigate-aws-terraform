resource "aws_iam_role" "fortinet" {
  name_prefix        = "fortinet-iam-role-"
  description        = "Consolidated role for Fortinet instances"
  tags               = merge(local.common_tags, { Name = "fortinet-iam-role" })
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
              "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "fortinet_policy" {
  name_prefix = "fortinet-iam-policy-"
  path        = "/"
  tags        = merge(local.common_tags, { Name = "fortinet-iam-policy" })
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:AssociateAddress",
                "ec2:AssignPrivateIpAddresses",
                "ec2:UnassignPrivateIpAddresses",
                "ec2:ReplaceRoute"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "fortinet_policy_attachment" {
  name       = "fortinet-policy-attachment"
  roles      = [aws_iam_role.fortinet.name]
  policy_arn = aws_iam_policy.fortinet_policy.arn
}

resource "aws_iam_instance_profile" "fortinet_iam" {
  name_prefix = "fortinet-iam-profile-"
  role        = aws_iam_role.fortinet.name
  tags        = merge(local.common_tags, { Name = "fortinet-instance-profile" })
}
