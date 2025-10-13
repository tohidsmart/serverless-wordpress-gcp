#!/bin/bash
set -e

PROJECT_ID=$1
REGION=${2:-us-central1}
SERVICE_IMAGE_TAG=${3:-latest}


if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <project-id> [region]"
    exit 1
fi

echo "=== Deploying WordPress to GCP ==="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Step 1: Enable minimum APIs
echo "Step 1/6: Enabling APIs..."
gcloud config set project $PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable storage.googleapis.com

# Step 2: Create Terraform state bucket
echo "Step 2/6: Creating state bucket..."
BUCKET_NAME="${PROJECT_ID}-terraform-state"
./scripts/bootstrap-state-bucket.sh $PROJECT_ID $REGION

# Step 3: Update main.tf with bucket name
echo "Step 3/6: Configuring Terraform backend..."
sed -i.bak "s/bucket = \".*\"/bucket = \"${BUCKET_NAME}\"/" terraform/main.tf

# Step 4: Run Terraform
echo "Step 4/6: Running Terraform..."
terraform -chdir=terraform init
terraform -chdir=terraform plan -var="project_id=${PROJECT_ID}"
terraform -chdir=terraform apply -var="project_id=${PROJECT_ID}" -auto-approve

# Step 5: Build and push WordPress image
echo "Step 5/6: Building and pushing WordPress image..."
DOCKER_IMAGE_REPO_PREFIX=$(terraform -chdir=terraform output -raw docker_image_prefix)
echo "Docker image repo: ${DOCKER_IMAGE_REPO_PREFIX}"
./scripts/docker-build-push.sh ${DOCKER_IMAGE_REPO_PREFIX} ${REGION} ${SERVICE_IMAGE_TAG}

# Step 6: Update Cloud Run with custom image
echo "Step 6/6: Updating Cloud Run with custom image..."
terraform -chdir=terraform plan -var="project_id=${PROJECT_ID}" -var="service_image_tag=${SERVICE_IMAGE_TAG}"
terraform -chdir=terraform apply -var="project_id=${PROJECT_ID}" -var="service_image_tag=${SERVICE_IMAGE_TAG}" -auto-approve

echo ""
echo "=== Deployment complete ==="
echo ""
echo "WordPress URL: $(terraform -chdir=terraform output -raw wordpress_url)"
echo "" 