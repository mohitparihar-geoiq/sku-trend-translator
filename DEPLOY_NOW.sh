#!/bin/bash

# ============================================================================
# AWS DEPLOYMENT SCRIPT - Ready to Run
# Copy-paste this entire script into AWS CloudShell and it handles everything
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
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# ============ CONFIG ============
PROJECT_NAME="trend-sku-translator"
AWS_REGION="us-east-1"
GIT_REPO="https://github.com/mohitparihar-geoiq/sku-trend-translator.git"

# Load credentials from environment or .env file
# DO NOT hardcode secrets here - use environment variables instead
if [ -f .env.docker ]; then
  export $(cat .env.docker | xargs)
fi

SERPER_API_KEY="${SERPER_API_KEY:-}"
TAVILY_API_KEY="${TAVILY_API_KEY:-}"
BEDROCK_API_KEY="${BEDROCK_API_KEY:-}"
BEDROCK_MODEL_ID="${BEDROCK_MODEL_ID:-us.anthropic.claude-sonnet-4-5-20250929-v1:0}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_DEFAULT_REGION="us-east-1"

echo -e "${YELLOW}⚠️  BEFORE YOU START:${NC}"
echo "1. Make sure you have AWS CLI installed"
echo "2. Verify GIT_REPO is set correctly"
echo "3. This will create resources in your AWS account"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Deployment cancelled"
  exit 0
fi

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 1: Clone Repository${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

cd /tmp
rm -rf sku-translator 2>/dev/null || true
git clone $GIT_REPO sku-translator
cd sku-translator

echo -e "${GREEN}✓ Repository cloned${NC}\n"

# ============ CREATE ECR REPO ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 2: Create ECR Repository${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

aws ecr create-repository \
  --repository-name $PROJECT_NAME \
  --region $AWS_REGION \
  --image-scan-on-push 2>/dev/null && echo -e "${GREEN}✓ ECR Repository created${NC}" || echo -e "${YELLOW}⚠ ECR Repository already exists${NC}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"

echo "ECR Repository URI: $ECR_URI"
echo ""

# ============ DOCKER LOGIN ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 3: Docker Login to ECR${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

echo -e "${GREEN}✓ Docker logged in to ECR${NC}\n"

# ============ BUILD IMAGE ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 4: Build Docker Image (this may take 2-3 minutes)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

docker build -t $PROJECT_NAME:latest .

echo -e "${GREEN}✓ Docker image built${NC}\n"

# ============ PUSH IMAGE ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 5: Push Image to ECR${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

docker tag $PROJECT_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo -e "${GREEN}✓ Docker image pushed to ECR${NC}\n"

# ============ CREATE IAM ROLE ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 6: Create IAM Role${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

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

# ============ DEPLOY TO APP RUNNER ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 7: Deploy to AWS App Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

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
        'AWS_DEFAULT_REGION'='$AWS_DEFAULT_REGION'
      }
    }
  }" \
  --instance-configuration "Cpu=1024,Memory=2048,InstanceRoleArn=$ROLE_ARN" \
  --auto-deployment-enabled \
  --region $AWS_REGION 2>/dev/null && echo -e "${GREEN}✓ App Runner service created${NC}" || echo -e "${YELLOW}⚠ Service already exists${NC}"

echo ""

# ============ GET SERVICE URL ============
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}STEP 8: Get Service URL (waiting 15 seconds)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

sleep 15

SERVICE_ARN=$(aws apprunner list-services \
  --region $AWS_REGION \
  --query "ServiceSummaryList[?ServiceName=='$PROJECT_NAME'].ServiceArn" \
  --output text)

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

echo -e "${GREEN}Deployment started at: $(date)${NC}"
echo ""
