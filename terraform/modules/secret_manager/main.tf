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
  Secret Manager Module

  Creates a single secret with one version
  - Can generate random password or use provided secret_data
  - Supports EU-only replication for GDPR
  - Optional IAM bindings for accessor members
 *****************************************/

# Generate random password if requested
resource "random_password" "password" {
  count = var.generate_random_password ? 1 : 0

  length           = var.password_length
  special          = var.password_special_chars
  override_special = "!@#$%^&*()-_=+[]{}:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = var.password_special_chars ? 2 : 0
}

locals {
  # Use generated password if enabled, otherwise use provided secret_data
  final_secret_data = var.generate_random_password ? random_password.password[0].result : var.secret_data
}

# Create the secret
resource "google_secret_manager_secret" "secret" {
  secret_id = var.secret_id
  project   = var.project_id

  labels = var.labels

  # Replication strategy
  dynamic "replication" {
    for_each = length(var.replication_locations) > 0 ? [1] : []
    content {
      user_managed {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }
  }

  dynamic "replication" {
    for_each = length(var.replication_locations) == 0 ? [1] : []
    content {
      automatic {}
    }
  }
}

# Create the secret version with the actual data
resource "google_secret_manager_secret_version" "version" {
  secret      = google_secret_manager_secret.secret.id
  secret_data = local.final_secret_data
}

# Grant access to specified members
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = toset(var.accessor_members)

  secret_id = google_secret_manager_secret.secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}
