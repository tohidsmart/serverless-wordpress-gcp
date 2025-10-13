#!/bin/bash
set -e

PROJECT_ID=$1
REGION=${2:-europe-west1}

if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <project-id> [region]"
    exit 1
fi

echo "=== Deploying WordPress to GCP ==="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Step 1: Enable minimum APIs
echo "Step 1/4: Enabling APIs..."
gcloud config set project $PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable storage.googleapis.com

# Step 2: Create Terraform state bucket
echo "Step 2/4: Creating state bucket..."
BUCKET_NAME="${PROJECT_ID}-terraform-state"
./scripts/bootstrap-state-bucket.sh $PROJECT_ID $REGION

# Step 3: Update main.tf with bucket name
echo "Step 3/4: Configuring Terraform backend..."
sed -i.bak "s/bucket = \".*\"/bucket = \"${BUCKET_NAME}\"/" terraform/main.tf

# Step 4: Run Terraform
echo "Step 4/4: Running Terraform..."
cd terraform
terraform init
terraform plan -var="project_id=${PROJECT_ID}"
terraform apply -var="project_id=${PROJECT_ID}"

echo ""
echo "=== Deployment complete ==="
echo ""
echo "WordPress URL: $(terraform output -raw wordpress_url)"
echo "" 