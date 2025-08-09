# Finantic Waitlist AWS Deployment Guide

This guide will help you deploy a fully functional waitlist form using AWS Lambda, API Gateway, and DynamoDB.

## Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   aws configure
   ```
   Enter your AWS Access Key ID, Secret Access Key, region, and output format.

2. **Node.js and npm installed** (for local development)

3. **Your existing S3 bucket name** where your React app is hosted

## Quick Deployment (Automated)

### Option 1: One-Click Deployment Script

1. **Update the configuration** in `deploy-aws-backend.sh`:
   ```bash
   # Edit these values at the top of the script
   AWS_REGION="us-east-1"  # Your preferred region
   S3_BUCKET_NAME="your-actual-s3-bucket-name"  # Your S3 bucket
   ```

2. **Run the deployment script**:
   ```bash
   ./deploy-aws-backend.sh
   ```

3. **Deploy your updated React app**:
   ```bash
   npm run build
   aws s3 sync build/ s3://your-s3-bucket-name --delete
   ```

That's it! Your waitlist form should now be functional.

## Manual Deployment (Step by Step)

If you prefer to run commands manually or need to troubleshoot:

### Step 1: Create DynamoDB Table

```bash
aws dynamodb create-table \
    --table-name finantic-waitlist \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

### Step 2: Create IAM Role for Lambda

```bash
# Create trust policy
cat > lambda-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name finantic-waitlist-handler-role \
    --assume-role-policy-document file://lambda-trust-policy.json

# Attach basic execution policy
aws iam attach-role-policy \
    --role-name finantic-waitlist-handler-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### Step 3: Create DynamoDB Policy

```bash
# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create DynamoDB policy
cat > dynamodb-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/finantic-waitlist"
    }
  ]
}
EOF

# Create and attach policy
aws iam create-policy \
    --policy-name finantic-waitlist-handler-dynamodb-policy \
    --policy-document file://dynamodb-policy.json

aws iam attach-role-policy \
    --role-name finantic-waitlist-handler-role \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/finantic-waitlist-handler-dynamodb-policy
```

### Step 4: Deploy Lambda Function

```bash
# Package the function
cd lambda
npm install --production
zip -r ../lambda-deployment.zip .
cd ..

# Deploy function (wait 10 seconds for IAM role to propagate)
sleep 10

aws lambda create-function \
    --function-name finantic-waitlist-handler \
    --runtime nodejs18.x \
    --role arn:aws:iam::${ACCOUNT_ID}:role/finantic-waitlist-handler-role \
    --handler waitlist-handler.handler \
    --zip-file fileb://lambda-deployment.zip \
    --timeout 30 \
    --memory-size 128 \
    --region us-east-1
```

### Step 5: Create API Gateway

```bash
# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name finantic-waitlist-api \
    --description "API for Finantic waitlist form" \
    --region us-east-1 \
    --query 'id' \
    --output text)

echo "API Gateway ID: $API_ID"

# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region us-east-1 \
    --query 'items[0].id' \
    --output text)

# Create waitlist resource
WAITLIST_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part waitlist \
    --region us-east-1 \
    --query 'id' \
    --output text)

# Create POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region us-east-1

# Create OPTIONS method for CORS
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region us-east-1

# Set up Lambda integration
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:${ACCOUNT_ID}:function:finantic-waitlist-handler/invocations \
    --region us-east-1

# Give API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name finantic-waitlist-handler \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn arn:aws:execute-api:us-east-1:${ACCOUNT_ID}:${API_ID}/*/* \
    --region us-east-1

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region us-east-1
```

### Step 6: Update Environment and Deploy React App

```bash
# Update .env.production with your API endpoint
echo "REACT_APP_API_ENDPOINT=https://${API_ID}.execute-api.us-east-1.amazonaws.com/prod/waitlist" > .env.production

# Build and deploy React app
npm run build
aws s3 sync build/ s3://your-s3-bucket-name --delete
```

## Testing Your Deployment

1. **Visit your website** and try submitting the waitlist form
2. **Check DynamoDB** for submissions:
   ```bash
   aws dynamodb scan --table-name finantic-waitlist --region us-east-1
   ```
3. **Check Lambda logs** if there are issues:
   ```bash
   aws logs describe-log-groups --log-group-name-prefix /aws/lambda/finantic-waitlist-handler
   ```

## Troubleshooting

### Common Issues:

1. **CORS Errors**: Make sure your API Gateway has OPTIONS method configured
2. **Lambda Timeout**: Check CloudWatch logs for the Lambda function
3. **Permission Errors**: Ensure IAM roles have correct policies attached
4. **API Gateway 502 Error**: Usually means Lambda function failed - check logs

### Useful Commands:

```bash
# View Lambda function logs
aws logs tail /aws/lambda/finantic-waitlist-handler --follow

# Test Lambda function directly
aws lambda invoke \
    --function-name finantic-waitlist-handler \
    --payload '{"httpMethod":"POST","body":"{\"name\":\"Test\",\"email\":\"test@example.com\"}"}' \
    response.json

# View DynamoDB items
aws dynamodb scan --table-name finantic-waitlist --region us-east-1
```

## Cost Estimation

For a typical waitlist with moderate traffic:
- **Lambda**: ~$0.20 per 1M requests
- **API Gateway**: ~$3.50 per 1M requests
- **DynamoDB**: ~$0.25 per 1M read/write operations
- **Total**: Usually under $1/month for most waitlists

## Cleanup (if needed)

To remove all resources:

```bash
# Delete Lambda function
aws lambda delete-function --function-name finantic-waitlist-handler

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id $API_ID

# Delete DynamoDB table
aws dynamodb delete-table --table-name finantic-waitlist

# Delete IAM role and policies
aws iam detach-role-policy --role-name finantic-waitlist-handler-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name finantic-waitlist-handler-role --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/finantic-waitlist-handler-dynamodb-policy
aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/finantic-waitlist-handler-dynamodb-policy
aws iam delete-role --role-name finantic-waitlist-handler-role