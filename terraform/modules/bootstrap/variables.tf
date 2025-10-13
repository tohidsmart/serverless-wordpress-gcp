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

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region for resources (use EU region for GDPR compliance)"
  type        = string
  default     = "europe-west1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "cms"
}

variable "artifact_registry_name" {
  description = "Name for the Artifact Registry repository"
  type        = string
  default     = "docker-images"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "cms-platform"
  }
}

variable "required_apis" {
  description = "List of required GCP APIs to enable"
  type        = set(string)
  default     = []

}
