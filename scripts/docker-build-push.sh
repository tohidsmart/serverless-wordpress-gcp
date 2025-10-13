#!/bin/bash
set -e

PROJECT_ID=${1:-}
IMAGE_TAG=${2:-latest}
REGION=${3:-europe-west1}

if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <project-id> [image-tag] [region]"
    echo "Example: $0 my-project v1.0.0 europe-west1"
    exit 1
fi

IMAGE_NAME="custom-wp"
REPO_NAME="docker-images"
IMAGE_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=== Building and pushing Docker image ==="
echo "Project: $PROJECT_ID"
echo "Image: $IMAGE_PATH"

# Configure Docker auth for Artifact Registry
echo "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Build image
echo "Building image..."
docker build -t ${IMAGE_PATH} ./wordpress

# Push image
echo "Pushing image..."
docker push ${IMAGE_PATH}

echo "✓ Image pushed: ${IMAGE_PATH}" 