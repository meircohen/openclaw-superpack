---
name: aws-cloud-ops
description: AWS development, infrastructure automation, and cloud architecture patterns
read_when: "user wants to work with AWS services, deploy to AWS, manage cloud infrastructure, or use AWS CLI"
---

# AWS Cloud Operations

Patterns for AWS development, deployment, and infrastructure management.

## AWS CLI Essentials

```bash
# Configure
aws configure
aws sts get-caller-identity  # Verify who you are

# S3
aws s3 ls
aws s3 cp local-file.txt s3://bucket/path/
aws s3 sync ./build s3://bucket/ --delete

# EC2
aws ec2 describe-instances --filters "Name=tag:Environment,Values=prod" --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table

# Lambda
aws lambda invoke --function-name my-func --payload '{"key":"value"}' output.json
aws lambda update-function-code --function-name my-func --zip-file fileb://function.zip

# CloudWatch Logs
aws logs tail /aws/lambda/my-func --follow
aws logs filter-log-events --log-group-name /aws/lambda/my-func --filter-pattern "ERROR" --start-time $(date -v-1H +%s)000

# SSM Parameter Store
aws ssm get-parameter --name "/app/prod/db-url" --with-decryption
aws ssm put-parameter --name "/app/prod/api-key" --type SecureString --value "secret"

# ECS
aws ecs list-services --cluster prod
aws ecs update-service --cluster prod --service api --force-new-deployment
```

## Architecture Patterns

### Serverless API
Lambda + API Gateway + DynamoDB + S3
- Use SAM or CDK for IaC
- Set concurrency limits on Lambda
- Enable X-Ray tracing

### Container Service
ECS Fargate + ALB + RDS + ElastiCache
- Use task definitions for versioning
- Blue/green deploys with CodeDeploy
- Private subnets for services, public for ALB

### Static Site + API
CloudFront + S3 + Lambda@Edge + API Gateway
- OAI for S3 access control
- Custom domain with ACM certificate

## Cost Management
```bash
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE
```

## Security Checklist
- [ ] Enable CloudTrail in all regions
- [ ] No IAM users with console access for services (use roles)
- [ ] S3 buckets: block public access by default
- [ ] Encrypt everything at rest (KMS)
- [ ] VPC flow logs enabled
- [ ] Security groups: least privilege, no 0.0.0.0/0 on SSH
