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
  description = "Default GCP region for regional resources"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# VPC Configuration
variable "routing_mode" {
  description = "Network routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "GLOBAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "routing_mode must be either REGIONAL or GLOBAL"
  }
}

variable "subnet_cidr" {
  description = "CIDR range for the main subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "secondary_ranges" {
  description = "Secondary IP ranges for the subnet (e.g., for GKE pods/services)"
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}

variable "firewall_rules" {
  description = "List of firewall rules"
  type        = list(any)
  default     = []
}

# Cloud NAT Configuration
variable "enable_nat" {
  description = "Enable Cloud NAT for outbound internet access"
  type        = bool
  default     = true
}

variable "nat_log_config" {
  description = "Cloud NAT logging configuration"
  type = object({
    enable = bool
    filter = string
  })
  default = {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Private Service Connection Configuration
variable "enable_private_service_connection" {
  description = "Enable Private Service Connection for Cloud SQL"
  type        = bool
  default     = true
}

variable "private_ip_prefix_length" {
  description = "Prefix length for private IP address range (for Cloud SQL)"
  type        = number
  default     = 20

  validation {
    condition     = var.private_ip_prefix_length >= 16 && var.private_ip_prefix_length <= 24
    error_message = "private_ip_prefix_length must be between 16 and 24"
  }
}
