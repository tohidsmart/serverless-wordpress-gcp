#!/bin/bash
set -e

DOCKER_IMAGE_REPO_PREFIX=${1:? Error: Artifact registry repository uri is required}
REGION=${2:? Error: Region is required}
IMAGE_TAG=${3:-latest}

IMAGE_NAME="custom-wp"
IMAGE_PATH="${DOCKER_IMAGE_REPO_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=== Building and pushing Docker image ==="
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