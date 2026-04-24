#!/bin/bash
# STEP 1: Clone Repository
set -e

PROJECT_NAME="trend-sku-translator"
GIT_REPO="https://github.com/mohitparihar-geoiq/sku-trend-translator.git"

echo "Cloning repository..."
cd /tmp
rm -rf sku-translator 2>/dev/null || true
git clone $GIT_REPO sku-translator
cd sku-translator

echo "✓ Repository cloned to /tmp/sku-translator"
echo "Next: Run STEP2_CreateECR.sh"
