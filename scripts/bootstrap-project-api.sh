#!/bin/bash
# Bootstrap minimum required APIs
set -e

PROJECT_ID=${1:-}

if [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <project-id>"
    exit 1
fi

echo "Enabling minimum required APIs for project: $PROJECT_ID"
gcloud config set project $PROJECT_ID

gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable storage.googleapis.com

echo "✓ APIs enabled"