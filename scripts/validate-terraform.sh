#!/bin/bash
# Copyright 2025
# Terraform validation script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Terraform validation...${NC}\n"

# Find all directories containing Terraform files, excluding .terraform
TERRAFORM_DIRS=$(find terraform -type f -name "*.tf" ! -path "*/.terraform/*" -exec dirname {} \; | sort -u)

# Counter for results
TOTAL=0
PASSED=0
FAILED=0

for dir in $TERRAFORM_DIRS; do
    echo -e "${YELLOW}Validating: ${dir}${NC}"
    TOTAL=$((TOTAL + 1))

    # Check formatting
    echo -n "  - Checking format... "
    if terraform fmt -check -recursive "$dir" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (needs formatting)${NC}"
        echo -e "${YELLOW}    Run: terraform fmt -recursive $dir${NC}"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Initialize without backend
    echo -n "  - Initializing... "
    if (cd "$dir" && terraform init -backend=false > /dev/null 2>&1); then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Validate
    echo -n "  - Validating... "
    if (cd "$dir" && terraform validate > /dev/null 2>&1); then
        echo -e "${GREEN}✓${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC}"
        (cd "$dir" && terraform validate)
        FAILED=$((FAILED + 1))
    fi

    echo ""
done

# Summary
echo -e "${YELLOW}================================${NC}"
echo -e "Total directories: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}================================${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Validation failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
fi
