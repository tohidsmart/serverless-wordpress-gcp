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
  Storage Module Outputs
 *****************************************/

output "bucket_name" {
  description = "Name of the storage bucket"
  value       = google_storage_bucket.bucket.name
}

output "bucket_url" {
  description = "URL of the storage bucket"
  value       = google_storage_bucket.bucket.url
}

output "bucket_self_link" {
  description = "Self link of the storage bucket"
  value       = google_storage_bucket.bucket.self_link
}

output "cdn_backend_id" {
  description = "ID of the CDN backend bucket (if enabled)"
  value       = try(google_compute_backend_bucket.cdn_backend[0].id, null)
}

output "cdn_backend_self_link" {
  description = "Self link of the CDN backend bucket (if enabled)"
  value       = try(google_compute_backend_bucket.cdn_backend[0].self_link, null)
}
