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


output "secret_id" {
  description = "The ID of the secret"
  value       = google_secret_manager_secret.secret.secret_id
}

output "secret_name" {
  description = "The full resource name of the secret (use this in Cloud Run secrets)"
  value       = google_secret_manager_secret.secret.name
}

output "version_name" {
  description = "The full resource name of the secret version"
  value       = google_secret_manager_secret_version.version.name
}

output "version_id" {
  description = "The version ID (e.g., 'latest' or '1')"
  value       = google_secret_manager_secret_version.version.version
}

output "generated_password" {
  description = "The generated password (only available if generate_random_password is true)"
  value       = var.generate_random_password ? random_password.password[0].result : null
  sensitive   = true
}

output "secret_data" {
  description = "The actual secret data (password)"
  value       = google_secret_manager_secret_version.version.secret_data
  sensitive   = true
}
