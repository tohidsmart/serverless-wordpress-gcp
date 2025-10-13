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
  Root Module Variables
 *****************************************/

# Project Configuration
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "Default GCP zone for resources"
  type        = list(string)
  default     = ["us-central1-a"]
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "cms"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    managed_by  = "terraform"
    purpose     = "cms-platform"
    environment = "production"
  }
}

# Bootstrap Module Variables
variable "artifact_registry_name" {
  description = "Name for the Artifact Registry repository"
  type        = string
  default     = "docker-images"
}


variable "required_apis" {
  description = "List of required GCP APIs to enable"
  type        = set(string)
  default = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "certificatemanager.googleapis.com",
    "dns.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "secretmanager.googleapis.com"

  ]
}


# Network Variables
variable "network_routing_mode" {
  description = "Network routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "GLOBAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.network_routing_mode)
    error_message = "network_routing_mode must be either REGIONAL or GLOBAL"
  }
}

variable "subnet_cidr" {
  description = "CIDR range for the main subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "enable_nat" {
  description = "Enable Cloud NAT for outbound internet access"
  type        = bool
  default     = true
}

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

variable "database_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "wp-instance"
}

variable "enable_cdn_for_media" {
  description = "Enable CDN for media storage bucket"
  type        = bool
  default     = false
}

# WordPress Configuration
# Note: wordpress_url is auto-constructed in main.tf as local.wordpress_url

variable "deployment_profile" {
  description = "Deployment profile"
  type        = string
  default     = "tiny"
}


variable "service_image_tag" {
  description = "The Worpress service container image tag"
  type        = string
  default     = null
}
