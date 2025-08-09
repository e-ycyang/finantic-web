#!/bin/bash

# Simple AWS Authentication Test Script
# Run this first to verify your AWS credentials before deployment

echo "🔐 Testing AWS Authentication..."
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed."
    echo "Please install it from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

echo "✅ AWS CLI is installed"

# Test basic authentication
echo "🔍 Testing AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS authentication successful!"
    
    # Display account information
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    REGION=$(aws configure get region)
    
    echo ""
    echo "📋 Your AWS Configuration:"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   User/Role:  $USER_ARN"
    echo "   Region:     $REGION"
    echo ""
    
    # Test basic permissions
    echo "🔍 Testing basic AWS permissions..."
    
    # Test S3 access
    if aws s3 ls &> /dev/null; then
        echo "✅ S3 access: OK"
    else
        echo "⚠️  S3 access: Limited or no access"
    fi
    
    # Test IAM access
    if aws iam get-user &> /dev/null; then
        echo "✅ IAM access: OK"
    else
        echo "⚠️  IAM access: Limited or no access"
    fi
    
    # Test Lambda access
    if aws lambda list-functions --max-items 1 &> /dev/null; then
        echo "✅ Lambda access: OK"
    else
        echo "⚠️  Lambda access: Limited or no access"
    fi
    
    # Test DynamoDB access
    if aws dynamodb list-tables --max-items 1 &> /dev/null; then
        echo "✅ DynamoDB access: OK"
    else
        echo "⚠️  DynamoDB access: Limited or no access"
    fi
    
    echo ""
    echo "🎉 Authentication test complete!"
    echo "You can now run: ./deploy-aws-backend.sh"
    
else
    echo "❌ AWS authentication failed!"
    echo ""
    echo "Common solutions:"
    echo "1. Run: aws configure"
    echo "   - Enter your AWS Access Key ID"
    echo "   - Enter your AWS Secret Access Key"
    echo "   - Set your default region (e.g., us-east-1)"
    echo "   - Set output format to: json"
    echo ""
    echo "2. If using AWS SSO:"
    echo "   aws sso login --profile your-profile-name"
    echo ""
    echo "3. Check environment variables:"
    echo "   echo \$AWS_ACCESS_KEY_ID"
    echo "   echo \$AWS_SECRET_ACCESS_KEY"
    echo ""
    echo "4. For more help, see: AWS_TROUBLESHOOTING.md"
    exit 1
fi