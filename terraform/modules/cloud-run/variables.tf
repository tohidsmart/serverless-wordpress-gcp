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
  Cloud Run Module Variables
 *****************************************/

# Project & Location
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = ""
}

variable "service_name" {
  description = "Name of the Cloud Run service (will be prefixed with name_prefix)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  type        = bool
  description = "Deletion protection"
  default     = false
}

variable "vpc_network_name" {
  type        = string
  description = "VPC network name to send traffic to"
}

variable "vpc_subnetwork_name" {
  type        = string
  description = "VPC subnetwork name"
  default     = ""
}

# Container Configuration
variable "containers" {
  description = "List of containers to run in the service"
  type = list(object({
    name                 = string
    image                = string
    container_port       = optional(number)
    port_name            = optional(string, "http1")
    cpu_limit            = optional(string, "1000m")
    memory_limit         = optional(string, "512Mi")
    cpu_always_allocated = optional(bool, false)
    startup_cpu_boost    = optional(bool, false)
    command              = optional(list(string), null)
    env_vars             = optional(map(string), {})
    secrets = optional(map(object({
      secret_name = string
      version     = string
    })), {})
    startup_probe = optional(object({
      initial_delay_seconds = optional(number, 0)
      timeout_seconds       = optional(number, 1)
      period_seconds        = optional(number, 10)
      failure_threshold     = optional(number, 3)
      http_get = optional(object({
        path = string
        port = optional(number)
      }))
    }))
    liveness_probe = optional(object({
      initial_delay_seconds = optional(number, 0)
      timeout_seconds       = optional(number, 1)
      period_seconds        = optional(number, 10)
      failure_threshold     = optional(number, 3)
      http_get = optional(object({
        path = string
        port = optional(number)
      }))
    }))
  }))
}

variable "timeout" {
  description = "Maximum request timeout in seconds (max 3600)"
  type        = string
  default     = "300s"
}

# Scaling Configuration
variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

# Network Configuration (Inversion of Control)
variable "vpc_egress_mode" {
  description = "VPC egress mode: ALL_TRAFFIC or PRIVATE_RANGES_ONLY"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress_mode)
    error_message = "vpc_egress_mode must be either ALL_TRAFFIC or PRIVATE_RANGES_ONLY"
  }
}

variable "ingress" {
  description = "Ingress settings: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    ], var.ingress)
    error_message = "ingress must be one of: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  }
}



# Traffic Configuration (Blue/Green deployments)
variable "traffic" {
  description = "Traffic configuration for the service"
  type = list(object({
    type     = optional(string, "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST")
    percent  = optional(number, 100)
    revision = optional(string)
    tag      = optional(string)
  }))
  default = [{
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }]
}

# IAM Configuration for Invokers
variable "invoker_members" {
  description = "Members who can invoke the Cloud Run service (e.g., 'allUsers', 'user:email@example.com')"
  type        = set(string)
  default     = []
}
