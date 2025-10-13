#!/bin/bash
# Copyright 2025
# Bootstrap script to create Terraform state bucket
# This script should be run BEFORE the first terraform init

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${1:-}"
REGION="${2:-europe-west1}"
BUCKET_NAME="${PROJECT_ID}-terraform-state"

# Display usage
usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 <project-id> [region]"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo "  project-id    GCP project ID (required)"
    echo "  region        GCS bucket region (default: europe-west1)"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  $0 my-gcp-project-id europe-west1"
    exit 1
}

# Validate arguments
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID is required${NC}\n"
    usage
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform State Bucket Bootstrap${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID:   $PROJECT_ID"
echo "  Region:       $REGION"
echo "  Bucket Name:  $BUCKET_NAME"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo -e "${YELLOW}Install from: https://cloud.google.com/sdk/docs/install${NC}"
    exit 1
fi

# Check if user is authenticated
echo -e "${YELLOW}Checking authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with gcloud${NC}"
    echo -e "${YELLOW}Run: gcloud auth login${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Authenticated${NC}"

# Set the active project
echo -e "${YELLOW}Setting active project...${NC}"
if ! gcloud config set project "$PROJECT_ID" &> /dev/null; then
    echo -e "${RED}Error: Failed to set project${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Project set to: $PROJECT_ID${NC}"

# Check if bucket already exists
echo -e "${YELLOW}Checking if bucket exists...${NC}"
if gcloud storage buckets describe "gs://$BUCKET_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠ Bucket already exists: gs://$BUCKET_NAME${NC}"
    echo -e "${GREEN}✓ Bucket is ready to use${NC}"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}✓ Bootstrap Complete${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Ensure backend config in terraform/main.tf:"
    echo "     terraform {"
    echo "       backend \"gcs\" {"
    echo "         bucket = \"$BUCKET_NAME\""
    echo "         prefix = \"terraform/state\""
    echo "       }"
    echo "     }"
    echo ""
    echo "  2. Initialize Terraform:"
    echo "     cd terraform"
    echo "     terraform init"
    echo ""
    exit 0
fi

echo -e "${YELLOW}Creating state bucket...${NC}"

# Create the bucket
if ! gcloud storage buckets create "gs://$BUCKET_NAME" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention 2>&1; then
    echo -e "${RED}Error: Failed to create bucket${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Bucket created: gs://$BUCKET_NAME${NC}"

# Enable versioning
echo -e "${YELLOW}Enabling versioning...${NC}"
if ! gcloud storage buckets update "gs://$BUCKET_NAME" \
    --versioning 2>&1; then
    echo -e "${RED}Error: Failed to enable versioning${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Add lifecycle rule to keep last 5 versions
echo -e "${YELLOW}Adding lifecycle rule...${NC}"
LIFECYCLE_CONFIG=$(cat <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "numNewerVersions": 5
        }
      }
    ]
  }
}
EOF
)

# Create temporary file for lifecycle config
TEMP_LIFECYCLE=$(mktemp)
echo "$LIFECYCLE_CONFIG" > "$TEMP_LIFECYCLE"

if ! gcloud storage buckets update "gs://$BUCKET_NAME" \
    --lifecycle-file="$TEMP_LIFECYCLE" 2>&1; then
    echo -e "${YELLOW}⚠ Warning: Failed to set lifecycle rule${NC}"
    echo -e "${YELLOW}  You can add it manually later${NC}"
fi

# Clean up temp file
rm -f "$TEMP_LIFECYCLE"

echo -e "${GREEN}✓ Lifecycle rule configured${NC}"

# Add labels
echo -e "${YELLOW}Adding labels...${NC}"
if ! gcloud storage buckets update "gs://$BUCKET_NAME" \
    --update-labels=managed_by=terraform,purpose=state-storage 2>&1; then
    echo -e "${YELLOW}⚠ Warning: Failed to add labels${NC}"
fi
echo -e "${GREEN}✓ Labels added${NC}"

# Display bucket info
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Bootstrap Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Bucket details:${NC}"
gcloud storage buckets describe "gs://$BUCKET_NAME" --format="table(
    name,
    location,
    storageClass,
    versioning.enabled,
    iamConfiguration.uniformBucketLevelAccess.enabled
)"

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Ensure backend config in terraform/main.tf:"
echo "     terraform {"
echo "       backend \"gcs\" {"
echo "         bucket = \"$BUCKET_NAME\""
echo "         prefix = \"terraform/state\""
echo "       }"
echo "     }"
echo ""
echo "  2. Initialize Terraform:"
echo "     cd terraform"
echo "     terraform init"
echo ""
echo -e "${GREEN}✓ Done!${NC}"
