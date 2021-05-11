// ======================
// VPC Flow logs
// ======================
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.naming_prefix}-vpc-flow-logs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge(local.mandatory_tags, {
    Name = "${local.naming_prefix}-vpc-flow-logs"
  })

}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.naming_prefix}-vpc-flow-logs"
  role = aws_iam_role.vpc_flow_logs.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "kms:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}