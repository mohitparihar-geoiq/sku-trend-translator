#!/bin/bash

# ============================================================================
# AWS CLOUDSHELL - PUSH DOCKER IMAGE TO ECR
# Copy-paste this entire script into AWS CloudShell
# ============================================================================

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ECR Push from CloudShell - SKU Translator               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# ============ CONFIGURATION ============
PROJECT_NAME="trend-sku-translator"
AWS_REGION="us-east-1"
GIT_REPO="https://github.com/mohitparihar-geoiq/sku-trend-translator.git"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: $PROJECT_NAME"
echo "  Region: $AWS_REGION"
echo ""

# ============ STEP 1: CLONE REPO ============
echo -e "${BLUE}STEP 1: Cloning Repository${NC}\n"

cd /tmp
rm -rf sku-translator 2>/dev/null || true
git clone $GIT_REPO sku-translator
cd sku-translator

echo -e "${GREEN}✓ Repository cloned${NC}\n"

# ============ STEP 2: GET AWS ACCOUNT ID ============
echo -e "${BLUE}STEP 2: Getting AWS Account ID${NC}\n"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"

echo "Account ID: $ACCOUNT_ID"
echo "ECR URI: $ECR_URI"
echo ""

# ============ STEP 3: CREATE ECR REPOSITORY ============
echo -e "${BLUE}STEP 3: Creating ECR Repository${NC}\n"

aws ecr create-repository \
  --repository-name $PROJECT_NAME \
  --region $AWS_REGION \
  --image-scan-on-push 2>/dev/null && echo -e "${GREEN}✓ Created new ECR repository${NC}" || echo -e "${GREEN}✓ ECR repository already exists${NC}"

echo ""

# ============ STEP 4: LOGIN TO ECR ============
echo -e "${BLUE}STEP 4: Authenticating Docker to ECR${NC}\n"

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

echo -e "${GREEN}✓ Docker authenticated${NC}\n"

# ============ STEP 5: BUILD IMAGE ============
echo -e "${BLUE}STEP 5: Building Docker Image (this takes 2-3 minutes)${NC}\n"

docker build -t $PROJECT_NAME:latest .

echo -e "${GREEN}✓ Image built${NC}\n"

# ============ STEP 6: TAG IMAGE ============
echo -e "${BLUE}STEP 6: Tagging Image${NC}\n"

docker tag $PROJECT_NAME:latest $ECR_URI:latest

echo -e "${GREEN}✓ Image tagged${NC}\n"

# ============ STEP 7: PUSH IMAGE ============
echo -e "${BLUE}STEP 7: Pushing Image to ECR (this takes a few minutes)${NC}\n"

docker push $ECR_URI:latest

echo -e "${GREEN}✓ Image pushed${NC}\n"

# ============ SUCCESS ============
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✅ PUSH SUCCESSFUL!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Your image is now in ECR:${NC}"
echo "  $ECR_URI:latest"
echo ""

echo -e "${BLUE}Next: Deploy to App Runner${NC}"
echo "  aws apprunner create-service --service-name $PROJECT_NAME --region $AWS_REGION ..."
echo ""

echo -e "${BLUE}View image in console:${NC}"
echo "  https://console.aws.amazon.com/ecr/repositories/$PROJECT_NAME?region=$AWS_REGION"
echo ""
