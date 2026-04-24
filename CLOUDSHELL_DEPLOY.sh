#!/bin/bash

# ============================================================================
# AWS CLOUDSHELL - COMPLETE DEPLOYMENT SCRIPT
# Copy-paste this entire script into AWS CloudShell
# Deploys Trend to SKU Translator to AWS App Runner
# ============================================================================

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AWS App Runner Deployment - Trend to SKU Translator    ║${NC}"
echo -e "${BLUE}║                   Complete Setup & Deploy                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# ============ CONFIG ============
PROJECT_NAME="trend-sku-translator"
AWS_REGION="us-east-1"
GIT_REPO="https://github.com/mohitparihar-geoiq/sku-trend-translator.git"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: $PROJECT_NAME"
echo "  Region: $AWS_REGION"
echo "  Git Repo: $GIT_REPO"
echo ""

# ============ STEP 1: PREREQUISITES ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 1: Checking Prerequisites${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS credentials configured (Account: $ACCOUNT_ID)${NC}\n"

# ============ STEP 2: CLONE REPO ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 2: Clone Repository${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

cd /tmp
rm -rf sku-translator 2>/dev/null || true
git clone $GIT_REPO sku-translator
cd sku-translator

echo -e "${GREEN}✓ Repository cloned${NC}\n"

# ============ STEP 3: CREATE ECR REPO ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 3: Create ECR Repository${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

aws ecr create-repository \
  --repository-name $PROJECT_NAME \
  --region $AWS_REGION \
  --image-scan-on-push 2>/dev/null && echo -e "${GREEN}✓ ECR Repository created${NC}" || echo -e "${YELLOW}⚠ ECR Repository already exists${NC}"

ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"

echo "ECR Repository URI: $ECR_URI"
echo ""

# ============ STEP 4: DOCKER LOGIN ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 4: Docker Login to ECR${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

echo -e "${GREEN}✓ Docker logged in to ECR${NC}\n"

# ============ STEP 5: BUILD IMAGE ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 5: Build Docker Image (this may take 2-3 minutes)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

docker build -t $PROJECT_NAME:latest .

echo -e "${GREEN}✓ Docker image built${NC}\n"

# ============ STEP 6: TAG & PUSH IMAGE ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 6: Tag & Push Image to ECR${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

docker tag $PROJECT_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo -e "${GREEN}✓ Docker image pushed to ECR${NC}\n"

# ============ STEP 7: CREATE IAM ROLE ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 7: Create IAM Role${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

ROLE_NAME="${PROJECT_NAME}-app-runner-role"

cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "apprunner.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --region $AWS_REGION 2>/dev/null && echo -e "${GREEN}✓ IAM Role created${NC}" || echo -e "${YELLOW}⚠ IAM Role already exists${NC}"

ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

echo "Role ARN: $ROLE_ARN"
echo ""

# ============ STEP 8: ENVIRONMENT VARIABLES ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 8: Environment Variables${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Provide your API credentials:${NC}\n"

read -p "SERPER_API_KEY: " SERPER_API_KEY
read -p "TAVILY_API_KEY: " TAVILY_API_KEY
read -p "BEDROCK_API_KEY: " BEDROCK_API_KEY
read -p "BEDROCK_MODEL_ID (default: us.anthropic.claude-sonnet-4-5-20250929-v1:0): " BEDROCK_MODEL_ID
BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-"us.anthropic.claude-sonnet-4-5-20250929-v1:0"}
read -p "AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
read -p "AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY

echo -e "${GREEN}✓ Credentials configured${NC}\n"

# ============ STEP 9: DEPLOY TO APP RUNNER ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 9: Deploy to AWS App Runner${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

aws apprunner create-service \
  --service-name $PROJECT_NAME \
  --source-configuration "ImageRepository={
    ImageIdentifier=$ECR_URI:latest,
    ImageRepositoryType=ECR,
    ImageConfiguration={
      Port=8000,
      RuntimeEnvironmentVariables={
        'SERPER_API_KEY'='$SERPER_API_KEY',
        'TAVILY_API_KEY'='$TAVILY_API_KEY',
        'BEDROCK_API_KEY'='$BEDROCK_API_KEY',
        'BEDROCK_MODEL_ID'='$BEDROCK_MODEL_ID',
        'AWS_ACCESS_KEY_ID'='$AWS_ACCESS_KEY_ID',
        'AWS_SECRET_ACCESS_KEY'='$AWS_SECRET_ACCESS_KEY',
        'AWS_DEFAULT_REGION'='$AWS_REGION'
      }
    }
  }" \
  --instance-configuration "Cpu=1024,Memory=2048,InstanceRoleArn=$ROLE_ARN" \
  --auto-deployment-enabled \
  --region $AWS_REGION 2>/dev/null && echo -e "${GREEN}✓ App Runner service created${NC}" || echo -e "${YELLOW}⚠ Service already exists or error occurred${NC}"

echo ""

# ============ STEP 10: GET SERVICE URL ============
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 10: Retrieve Service URL (waiting 20 seconds)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

sleep 20

SERVICE_ARN=$(aws apprunner list-services \
  --region $AWS_REGION \
  --query "ServiceSummaryList[?ServiceName=='$PROJECT_NAME'].ServiceArn" \
  --output text)

if [ -z "$SERVICE_ARN" ]; then
    echo -e "${YELLOW}⚠ Service ARN not found yet. It may still be initializing.${NC}"
    echo "Check the AWS Console: https://console.aws.amazon.com/apprunner/home?region=$AWS_REGION#/services"
else
    SERVICE_URL=$(aws apprunner describe-service \
      --service-arn $SERVICE_ARN \
      --region $AWS_REGION \
      --query 'ServiceDetail.ServiceUrl' \
      --output text)

    # ============ SUCCESS ============
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  ✅ DEPLOYMENT SUCCESSFUL!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${BLUE}📱 Your Application:${NC}"
    echo "   https://$SERVICE_URL"
    echo ""

    echo -e "${BLUE}🏥 Health Check:${NC}"
    echo "   https://$SERVICE_URL/health"
    echo ""
fi

echo -e "${BLUE}📊 AWS Console Links:${NC}"
echo "   App Runner: https://console.aws.amazon.com/apprunner/home?region=$AWS_REGION#/services"
echo "   ECR: https://console.aws.amazon.com/ecr/repositories/$PROJECT_NAME?region=$AWS_REGION"
echo ""

echo -e "${BLUE}📋 Useful Commands:${NC}"
echo ""
echo "View logs:"
echo "  aws logs tail /aws/apprunner/$PROJECT_NAME/service_deployment --follow --region $AWS_REGION"
echo ""
echo "Check service status:"
echo "  aws apprunner describe-service --service-arn $SERVICE_ARN --region $AWS_REGION"
echo ""
echo "Stop the service:"
echo "  aws apprunner delete-service --service-arn $SERVICE_ARN --region $AWS_REGION"
echo ""

echo -e "${YELLOW}⏳ NOTE: Service may take 2-5 minutes to be fully ready.${NC}"
echo -e "${YELLOW}   Check the health endpoint after a few minutes.${NC}"
echo ""

echo -e "${GREEN}Deployment completed at: $(date)${NC}"
