/**
 * Copyright 2025
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/******************************************
  Bootstrap Module
  - Enables required APIs
  - Creates service accounts
  - Sets up Terraform state bucket
  - Creates Artifact Registry
  - Optional: Workload Identity Federation for GitHub
 *****************************************/

locals {
  # Service account names
  terraform_sa_name = "${var.name_prefix}-terraform"
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset(var.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Terraform service account (for CI/CD deployments)
resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = local.terraform_sa_name
  display_name = "Terraform Service Account"
  description  = "Service account for Terraform deployments"

  depends_on = [google_project_service.required_apis]
}

# IAM bindings for Terraform service account
resource "google_project_iam_member" "terraform_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_security_admin" {
  project = var.project_id
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_name
  description   = "Docker repository for container images"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.required_apis]
}

# IAM for Artifact Registry
resource "google_artifact_registry_repository_iam_member" "terraform_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.terraform.email}"
}

