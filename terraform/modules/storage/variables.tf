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
  Storage Module Variables
 *****************************************/

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the storage bucket (will be prefixed if name_prefix is set)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = ""
}

variable "location" {
  description = "Bucket location (region or multi-region)"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Storage class for the bucket (STANDARD, NEARLINE, COLDLINE, ARCHIVE)"
  type        = string
  default     = "STANDARD"
}

variable "uniform_bucket_level_access" {
  description = "Enable uniform bucket-level access"
  type        = bool
  default     = true
}

variable "public_access_prevention" {
  description = "Public access prevention setting (inherited or enforced)"
  type        = string
  default     = "enforced"
}

variable "versioning_enabled" {
  description = "Enable object versioning"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow bucket deletion even when containing objects"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default     = {}
}

# Lifecycle Rules
variable "lifecycle_rules" {
  description = "List of lifecycle rules for the bucket"
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      created_before             = optional(string)
      with_state                 = optional(string)
      matches_storage_class      = optional(list(string))
      num_newer_versions         = optional(number)
      days_since_noncurrent_time = optional(number)
    })
  }))
  default = []
}

# CORS Configuration
variable "cors_config" {
  description = "CORS configuration for the bucket"
  type = object({
    origin          = list(string)
    method          = list(string)
    response_header = list(string)
    max_age_seconds = number
  })
  default = null
}

# IAM Members
variable "iam_members" {
  description = "List of IAM members with their roles"
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

# CDN Configuration
variable "enable_cdn" {
  description = "Enable Cloud CDN backend bucket"
  type        = bool
  default     = false
}

variable "cdn_cache_mode" {
  description = "CDN cache mode (CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL)"
  type        = string
  default     = "CACHE_ALL_STATIC"
}

variable "cdn_client_ttl" {
  description = "CDN client TTL in seconds"
  type        = number
  default     = 3600
}

variable "cdn_default_ttl" {
  description = "CDN default TTL in seconds"
  type        = number
  default     = 3600
}

variable "cdn_max_ttl" {
  description = "CDN max TTL in seconds"
  type        = number
  default     = 86400
}

variable "cdn_negative_caching" {
  description = "Enable CDN negative caching"
  type        = bool
  default     = false
}

variable "cdn_serve_while_stale" {
  description = "Serve stale content while revalidating"
  type        = number
  default     = 0
}
