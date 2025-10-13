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

variable "secret_id" {
  description = "ID of the secret (e.g., wordpress-db-password)"
  type        = string
}

variable "secret_data" {
  description = "The secret data (password, API key, etc.). If not provided, a random password will be generated."
  type        = string
  sensitive   = true
  default     = null
}

variable "generate_random_password" {
  description = "Whether to generate a random password. If true, secret_data will be ignored."
  type        = bool
  default     = false
}

variable "password_length" {
  description = "Length of the generated password (only used if generate_random_password is true)"
  type        = number
  default     = 32
}

variable "password_special_chars" {
  description = "Include special characters in generated password"
  type        = bool
  default     = true
}

variable "replication_locations" {
  description = "List of regions for replication (empty for automatic)"
  type        = list(string)
  default     = []
}

variable "accessor_members" {
  description = "List of members who can access this secret (e.g., serviceAccount:email@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to the secret"
  type        = map(string)
  default     = {}
}
