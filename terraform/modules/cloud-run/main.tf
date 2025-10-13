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
  Cloud Run Module

  Lightweight, composable module for deploying
  Cloud Run services with dedicated service accounts
  and resource-level IAM bindings.

  Features:
  - Dedicated service account per service
  - Resource-level IAM bindings (NOT project-level)
  - VPC connector support (optional)
  - Environment variables and secrets
  - Traffic splitting support
 *****************************************/

locals {
  service_name = "${var.name_prefix}-${var.service_name}"
}

# Service Account for Cloud Run
resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "${local.service_name}-sa"
  display_name = "Service Account for ${local.service_name}"
  description  = "Service account for Cloud Run service ${local.service_name}"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "service" {
  project             = var.project_id
  name                = local.service_name
  location            = var.region
  ingress             = var.ingress
  deletion_protection = var.deletion_protection

  labels = var.labels


  template {
    service_account = google_service_account.cloud_run.email
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = var.vpc_network_name
        subnetwork = var.vpc_subnetwork_name
      }
    }

    # Scaling configuration
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Container configuration (supports multiple containers)
    dynamic "containers" {
      for_each = var.containers
      content {
        name    = containers.value.name
        image   = containers.value.image
        command = containers.value.command

        # Resource limits
        resources {
          limits = {
            cpu    = containers.value.cpu_limit
            memory = containers.value.memory_limit
          }
          cpu_idle          = containers.value.cpu_always_allocated ? false : true
          startup_cpu_boost = containers.value.startup_cpu_boost
        }

        # Environment variables (composable)
        dynamic "env" {
          for_each = containers.value.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secrets from Secret Manager (composable)
        dynamic "env" {
          for_each = containers.value.secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret_name
                version = env.value.version
              }
            }
          }
        }

        # Container ports
        dynamic "ports" {
          for_each = containers.value.container_port != null ? [1] : []
          content {
            container_port = containers.value.container_port
            name           = containers.value.port_name
          }
        }

        # Startup probe (optional)
        dynamic "startup_probe" {
          for_each = containers.value.startup_probe != null ? [containers.value.startup_probe] : []
          content {
            initial_delay_seconds = startup_probe.value.initial_delay_seconds
            timeout_seconds       = startup_probe.value.timeout_seconds
            period_seconds        = startup_probe.value.period_seconds
            failure_threshold     = startup_probe.value.failure_threshold

            dynamic "http_get" {
              for_each = startup_probe.value.http_get != null ? [startup_probe.value.http_get] : []
              content {
                path = http_get.value.path
                port = http_get.value.port
              }
            }
          }
        }

        # Liveness probe (optional)
        dynamic "liveness_probe" {
          for_each = containers.value.liveness_probe != null ? [containers.value.liveness_probe] : []
          content {
            initial_delay_seconds = liveness_probe.value.initial_delay_seconds
            timeout_seconds       = liveness_probe.value.timeout_seconds
            period_seconds        = liveness_probe.value.period_seconds
            failure_threshold     = liveness_probe.value.failure_threshold

            dynamic "http_get" {
              for_each = liveness_probe.value.http_get != null ? [liveness_probe.value.http_get] : []
              content {
                path = http_get.value.path
                port = http_get.value.port
              }
            }
          }
        }
      }
    }

    # Execution environment
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    # Max request timeout
    timeout = var.timeout
  }

  # Traffic configuration (supports blue/green deployments)
  dynamic "traffic" {
    for_each = var.traffic
    content {
      type     = traffic.value.type
      percent  = traffic.value.percent
      revision = traffic.value.revision
      tag      = traffic.value.tag
    }
  }

  depends_on = [
    google_service_account.cloud_run
  ]
}

# IAM policy for Cloud Run service (who can invoke)
# This is resource-level IAM, so it stays in the module
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = var.invoker_members

  project  = google_cloud_run_v2_service.service.project
  location = google_cloud_run_v2_service.service.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = each.value
}
