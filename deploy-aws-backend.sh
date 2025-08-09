#!/bin/bash

# Finantic Waitlist Backend Deployment Script
# This script sets up the complete AWS infrastructure for the waitlist form

set -e  # Exit on any error

# Configuration - UPDATE THESE VALUES
AWS_REGION="ca-central-1"  # Change to your preferred region
LAMBDA_FUNCTION_NAME="finantic-waitlist-handler"
API_GATEWAY_NAME="finantic-waitlist-api"
DYNAMODB_TABLE_NAME="finantic-waitlist"
S3_BUCKET_NAME="finantic-website"  # Your existing S3 bucket name

echo "🚀 Starting Finantic Waitlist Backend Deployment..."
echo "Region: $AWS_REGION"
echo "Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "API Gateway: $API_GATEWAY_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo ""
# Pre-flight checks
echo "🔍 Running pre-flight checks..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first:"
    echo "   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check AWS authentication
echo "🔐 Checking AWS authentication..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS authentication failed!"
    echo ""
    echo "Please fix your AWS credentials:"
    echo "1. Run: aws configure"
    echo "2. Enter your AWS Access Key ID and Secret Access Key"
    echo "3. Set region to: $AWS_REGION"
    echo "4. Set output format to: json"
    echo ""
    echo "For more help, see: AWS_TROUBLESHOOTING.md"
    exit 1
fi

# Get and display account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "✅ Authenticated as: $USER_ARN"
echo "✅ Account ID: $ACCOUNT_ID"
echo ""

# Check if required tools are available
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install Node.js and npm first."
    exit 1
fi

if ! command -v zip &> /dev/null; then
    echo "❌ zip command is not available. Please install zip utility."
    exit 1
fi

echo "✅ All pre-flight checks passed!"
echo ""

# Step 1: Create DynamoDB Table
echo "📊 Creating DynamoDB table..."
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE_NAME \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $AWS_REGION

echo "⏳ Waiting for DynamoDB table to be active..."
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE_NAME --region $AWS_REGION
echo "✅ DynamoDB table created successfully!"

# Step 2: Create IAM Role for Lambda
echo "🔐 Creating IAM role for Lambda..."
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

aws iam create-role \
    --role-name ${LAMBDA_FUNCTION_NAME}-role \
    --assume-role-policy-document file://lambda-trust-policy.json

# Attach basic Lambda execution policy
aws iam attach-role-policy \
    --role-name ${LAMBDA_FUNCTION_NAME}-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create and attach DynamoDB policy
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
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:*:table/${DYNAMODB_TABLE_NAME}"
    }
  ]
}
EOF

aws iam create-policy \
    --policy-name ${LAMBDA_FUNCTION_NAME}-dynamodb-policy \
    --policy-document file://dynamodb-policy.json

# Get account ID for policy ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam attach-role-policy \
    --role-name ${LAMBDA_FUNCTION_NAME}-role \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${LAMBDA_FUNCTION_NAME}-dynamodb-policy

echo "✅ IAM role created successfully!"

# Step 3: Package and Deploy Lambda Function
echo "📦 Packaging Lambda function..."
cd lambda
npm install --production
zip -r ../lambda-deployment.zip .
cd ..

echo "🚀 Deploying Lambda function..."
# Wait a bit for IAM role to propagate
sleep 10

aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime nodejs18.x \
    --role arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_FUNCTION_NAME}-role \
    --handler waitlist-handler.handler \
    --zip-file fileb://lambda-deployment.zip \
    --timeout 30 \
    --memory-size 128 \
    --region $AWS_REGION

echo "✅ Lambda function deployed successfully!"

# Step 4: Create API Gateway
echo "🌐 Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
    --name $API_GATEWAY_NAME \
    --description "API for Finantic waitlist form" \
    --region $AWS_REGION \
    --query 'id' \
    --output text)

echo "API Gateway ID: $API_ID"

# Get the root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $AWS_REGION \
    --query 'items[0].id' \
    --output text)

# Create waitlist resource
WAITLIST_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part waitlist \
    --region $AWS_REGION \
    --query 'id' \
    --output text)

# Create POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $AWS_REGION

# Create OPTIONS method for CORS
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region $AWS_REGION

# Set up Lambda integration for POST
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${LAMBDA_FUNCTION_NAME}/invocations \
    --region $AWS_REGION

# Set up mock integration for OPTIONS (CORS preflight)
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
    --region $AWS_REGION

# Set up method response for OPTIONS
aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters method.response.header.Access-Control-Allow-Headers=false,method.response.header.Access-Control-Allow-Methods=false,method.response.header.Access-Control-Allow-Origin=false \
    --region $AWS_REGION

# Set up integration response for OPTIONS
aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $WAITLIST_RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'GET,POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
    --region $AWS_REGION

# Give API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION_NAME \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/*arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/* \
    --region $AWS_REGION

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $AWS_REGION

echo "✅ API Gateway created successfully!"

# Step 5: Update environment file with actual API endpoint
API_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/waitlist"
echo "🔧 Updating .env.production with API endpoint..."
echo "REACT_APP_API_ENDPOINT=${API_ENDPOINT}" > .env.production

echo ""
echo "🎉 Deployment Complete!"
echo "=================================="
echo "API Endpoint: $API_ENDPOINT"
echo "DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo "Lambda Function: $LAMBDA_FUNCTION_NAME"
echo ""
echo "Next Steps:"
echo "1. Build your React app: npm run build"
echo "2. Deploy to S3: aws s3 sync build/ s3://$S3_BUCKET_NAME --delete"
echo "3. Test your waitlist form!"
echo ""
echo "To view waitlist submissions:"
echo "aws dynamodb scan --table-name $DYNAMODB_TABLE_NAME --region $AWS_REGION"

# Cleanup temporary files
rm -f lambda-trust-policy.json dynamodb-policy.json lambda-deployment.zip

echo "✅ Cleanup complete!"