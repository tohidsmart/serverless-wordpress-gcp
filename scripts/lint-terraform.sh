#!/bin/bash
# Copyright 2025
# TFLint script for Terraform modules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting TFLint...${NC}\n"

# Check if tflint is installed
if ! command -v tflint &> /dev/null; then
    echo -e "${RED}tflint is not installed!${NC}"
    echo -e "${YELLOW}Install with:${NC}"
    echo "  curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
    echo "  or visit: https://github.com/terraform-linters/tflint"
    exit 1
fi

# Initialize tflint plugins
echo -e "${YELLOW}Initializing tflint plugins...${NC}"
tflint --init

# Find all directories containing Terraform files, excluding .terraform
TERRAFORM_DIRS=$(find terraform -type f -name "*.tf" ! -path "*/.terraform/*" -exec dirname {} \; | sort -u)

# Counter for results
TOTAL=0
PASSED=0
FAILED=0

for dir in $TERRAFORM_DIRS; do
    echo -e "${YELLOW}Linting: ${dir}${NC}"
    TOTAL=$((TOTAL + 1))

    if (cd "$dir" && tflint --config="$PWD/.tflint.hcl"); then
        echo -e "${GREEN}✓ Passed${NC}\n"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ Failed${NC}\n"
        FAILED=$((FAILED + 1))
    fi
done

# Summary
echo -e "${YELLOW}================================${NC}"
echo -e "Total directories: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}================================${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Linting failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All linting passed!${NC}"
    exit 0
fi
