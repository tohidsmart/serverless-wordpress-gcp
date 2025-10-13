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
  Cloud Run Module Outputs
 *****************************************/

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.name
}

output "service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.uri
}

output "service_id" {
  description = "The ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.id
}

output "service_location" {
  description = "The location of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.location
}

output "service_account_email" {
  description = "The email of the service account used by Cloud Run (use this for resource-level IAM bindings)"
  value       = google_service_account.cloud_run.email
}

output "service_account_id" {
  description = "The ID of the service account"
  value       = google_service_account.cloud_run.id
}

output "service_account_name" {
  description = "The name of the service account"
  value       = google_service_account.cloud_run.name
}


output "latest_revision" {
  description = "The name of the latest revision"
  value       = google_cloud_run_v2_service.service.latest_ready_revision
}

output "terminal_condition" {
  description = "The terminal condition of the service"
  value       = google_cloud_run_v2_service.service.terminal_condition
}
