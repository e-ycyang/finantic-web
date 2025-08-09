# AWS Authentication Troubleshooting Guide

## Error: "The security token included in the request is invalid"

This error occurs when your AWS credentials are expired, invalid, or not properly configured.

## Quick Fixes:

### 1. Check AWS CLI Configuration
```bash
# Verify your current AWS configuration
aws configure list

# Check if you can access AWS services
aws sts get-caller-identity
```

### 2. Reconfigure AWS CLI
```bash
# Reconfigure with fresh credentials
aws configure

# You'll need:
# - AWS Access Key ID
# - AWS Secret Access Key  
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### 3. If Using AWS SSO or Temporary Credentials
```bash
# For AWS SSO users
aws sso login --profile your-profile-name

# For temporary credentials, you may need to refresh
aws sts get-session-token
```

### 4. Check Environment Variables
```bash
# These might override your AWS CLI config
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $AWS_SESSION_TOKEN

# If set incorrectly, unset them:
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
```

### 5. Verify IAM Permissions
Your AWS user/role needs these permissions:
- `dynamodb:CreateTable`
- `dynamodb:PutItem`
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:CreatePolicy`
- `lambda:CreateFunction`
- `lambda:AddPermission`
- `apigateway:*`
- `sts:GetCallerIdentity`

## Step-by-Step Resolution:

1. **Get fresh credentials from AWS Console:**
   - Go to AWS Console → IAM → Users → Your User → Security Credentials
   - Create new Access Key if needed

2. **Reconfigure AWS CLI:**
   ```bash
   aws configure
   ```

3. **Test authentication:**
   ```bash
   aws sts get-caller-identity
   ```
   Should return your account ID, user ARN, etc.

4. **Run deployment again:**
   ```bash
   ./deploy-aws-backend.sh
   ```

## Alternative: Manual Step-by-Step Deployment

If the automated script continues to fail, follow the manual steps in `AWS_DEPLOYMENT_GUIDE.md` one command at a time to identify exactly where the authentication fails.

## Common Scenarios:

### Scenario 1: Corporate AWS Account
- You might need to use AWS SSO or assume a role
- Contact your AWS administrator for proper credentials

### Scenario 2: Personal AWS Account
- Ensure you have programmatic access enabled
- Check if MFA is required for API access

### Scenario 3: Expired Credentials
- AWS temporary credentials expire after a few hours
- Refresh your session or get new permanent credentials

## Testing Your Fix:
```bash
# This should work without errors:
aws sts get-caller-identity

# This should list your S3 buckets:
aws s3 ls

# If both work, try the deployment script again
./deploy-aws-backend.sh