#!/bin/bash

# Deploy remaining AWS resources (skipping existing DynamoDB table)
set -e

# Configuration
AWS_REGION="ca-central-1"
LAMBDA_FUNCTION_NAME="finantic-waitlist-handler"
API_GATEWAY_NAME="finantic-waitlist-api"
DYNAMODB_TABLE_NAME="finantic-waitlist"
S3_BUCKET_NAME="finantic-website"

echo "🚀 Deploying remaining AWS resources..."
echo "Region: $AWS_REGION"
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Step 1: Create IAM Role for Lambda (if it doesn't exist)
echo "🔐 Creating IAM role for Lambda..."

# Check if role exists
if aws iam get-role --role-name ${LAMBDA_FUNCTION_NAME}-role &> /dev/null; then
    echo "✅ IAM role already exists, skipping creation"
else
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

    aws iam attach-role-policy \
        --role-name ${LAMBDA_FUNCTION_NAME}-role \
        --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${LAMBDA_FUNCTION_NAME}-dynamodb-policy

    echo "✅ IAM role created successfully!"
    echo "⏳ Waiting 10 seconds for IAM role to propagate..."
    sleep 10
fi

# Step 2: Package and Deploy Lambda Function
echo "📦 Packaging Lambda function..."
cd lambda
npm install --production
zip -r ../lambda-deployment.zip .
cd ..

echo "🚀 Deploying Lambda function..."
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

# Step 3: Create API Gateway
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
    --source-arn arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/* \
    --region $AWS_REGION

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $AWS_REGION

echo "✅ API Gateway created successfully!"

# Step 4: Update environment file with actual API endpoint
API_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/waitlist"
echo "🔧 Updating .env.production with API endpoint..."
echo "REACT_APP_API_ENDPOINT=${API_ENDPOINT}" > .env.production

echo ""
echo "🎉 Deployment Complete!"
echo "=================================="
echo "API Endpoint: $API_ENDPOINT"
echo "DynamoDB Table: $DYNAMODB_TABLE_NAME (already existed)"
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