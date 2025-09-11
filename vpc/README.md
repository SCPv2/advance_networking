# VPC 네트워크 설계 및 구현

S3 Bucket Polity

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAccessOnlyFromSpecificVPCE",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::ceweb123",
        "arn:aws:s3:::ceweb123/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:SourceVpce": "vpce-03a8a75c77f8efce0"
        }
      }
    }
  ]
}
```
