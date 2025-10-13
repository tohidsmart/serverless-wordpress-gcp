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
  Storage Module - Cloud Storage Buckets

  Provides GCS buckets for:
  - Media/static file storage
  - Shared storage across instances
  - CDN integration ready
  - Lifecycle management
  - Versioning and retention
 *****************************************/

locals {
  bucket_name = var.name_prefix != "" ? "${var.name_prefix}-${var.bucket_name}" : var.bucket_name
}

/******************************************
  Storage Bucket
 *****************************************/

resource "google_storage_bucket" "bucket" {
  name          = local.bucket_name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class

  uniform_bucket_level_access = var.uniform_bucket_level_access

  # Public access prevention
  public_access_prevention = var.public_access_prevention

  # Versioning
  dynamic "versioning" {
    for_each = var.versioning_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  # Lifecycle rules
  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }

      condition {
        age                        = try(lifecycle_rule.value.condition.age, null)
        created_before             = try(lifecycle_rule.value.condition.created_before, null)
        with_state                 = try(lifecycle_rule.value.condition.with_state, null)
        matches_storage_class      = try(lifecycle_rule.value.condition.matches_storage_class, null)
        num_newer_versions         = try(lifecycle_rule.value.condition.num_newer_versions, null)
        days_since_noncurrent_time = try(lifecycle_rule.value.condition.days_since_noncurrent_time, null)
      }
    }
  }

  # CORS configuration for media serving
  dynamic "cors" {
    for_each = var.cors_config != null ? [var.cors_config] : []
    content {
      origin          = cors.value.origin
      method          = cors.value.method
      response_header = cors.value.response_header
      max_age_seconds = cors.value.max_age_seconds
    }
  }

  labels = var.labels

  force_destroy = var.force_destroy
}

/******************************************
  IAM Bindings
 *****************************************/

resource "google_storage_bucket_iam_member" "members" {
  for_each = { for idx, member in var.iam_members : idx => member }

  bucket = google_storage_bucket.bucket.name
  role   = each.value.role
  member = each.value.member
}

/******************************************
  CDN Backend Bucket (Optional)
 *****************************************/

resource "google_compute_backend_bucket" "cdn_backend" {
  count = var.enable_cdn ? 1 : 0

  name        = "${local.bucket_name}-cdn-backend"
  project     = var.project_id
  bucket_name = google_storage_bucket.bucket.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = var.cdn_cache_mode
    client_ttl        = var.cdn_client_ttl
    default_ttl       = var.cdn_default_ttl
    max_ttl           = var.cdn_max_ttl
    negative_caching  = var.cdn_negative_caching
    serve_while_stale = var.cdn_serve_while_stale
  }
}
