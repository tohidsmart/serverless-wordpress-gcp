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
  Root Module - CMS Platform on GCP

  This module orchestrates the complete
  infrastructure for a CMS platform on
  Google Cloud Platform.
 *****************************************/



terraform {
  backend "gcs" {
    bucket = ""
    prefix = "wp"
  }
}

# Get current project details
data "google_project" "current" {
  project_id = var.project_id
}

# Map profile to infrastructure resources
locals {
  # Auto-construct WordPress URL based on Cloud Run naming convention
  wordpress_url = "https://${var.name_prefix}-wordpress-${data.google_project.current.number}.${var.region}.run.app"

  profile_config = {
    tiny = {
      db_tier            = "db-f1-micro"
      cpu_limit          = "1000m" # 1 vCPU
      memory_limit       = "512Mi" # 512MB RAM
      min_instances      = 0
      max_instances      = 3
      enable_lb          = false
      log_retention      = 90
      estimated_cost_usd = "12-18"
    }
    small = {
      db_tier            = "db-f1-micro"
      cpu_limit          = "2000m" # 2 vCPUs
      memory_limit       = "2Gi"   # 1GB RAM
      min_instances      = 0
      max_instances      = 5
      enable_lb          = false
      log_retention      = 365
      estimated_cost_usd = "30-40"
    }

  }

  config = local.profile_config[var.deployment_profile]
}

# Bootstrap: APIs, service accounts, state bucket, artifact registry
module "bootstrap" {
  source = "./modules/bootstrap"

  project_id             = var.project_id
  region                 = var.region
  name_prefix            = var.name_prefix
  artifact_registry_name = var.artifact_registry_name

  required_apis = var.required_apis
  labels        = var.labels
}

# Networking: VPC, subnets, Cloud NAT
module "network" {
  source = "./modules/network"

  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix

  # Network configuration
  routing_mode = var.network_routing_mode
  subnet_cidr  = var.subnet_cidr

  # Cloud NAT
  enable_nat = var.enable_nat

  # Private Service Connection for Cloud SQL
  enable_private_service_connection = var.enable_private_service_connection
  private_ip_prefix_length          = var.private_ip_prefix_length

  depends_on = [module.bootstrap]
}

# Secret Manager: WordPress Database Password (randomly generated)
module "wordpress_db_password" {
  source = "./modules/secret_manager"

  project_id               = var.project_id
  secret_id                = "wordpress-db-password"
  generate_random_password = true
  password_length          = 10
  password_special_chars   = true

  # Multi-region replication for high availability
  replication_locations = ["us-central1", "us-east1"]

  labels = merge(var.labels, {
    purpose = "database-credentials"
  })

  depends_on = [module.bootstrap]
}

module "wordpress_admin_password" {
  source = "./modules/secret_manager"

  project_id               = var.project_id
  secret_id                = "wordpress-admin-password"
  generate_random_password = true
  password_length          = 10
  password_special_chars   = true

  # Multi-region replication for high availability
  replication_locations = ["us-central1", "us-east1"]

  labels = merge(var.labels, {
    purpose = "admin-credentials"
  })

  depends_on = [module.bootstrap]
}

module "mysql_db" {
  source  = "terraform-google-modules/sql-db/google//modules/safer_mysql"
  version = "~> 26.0"


  name                 = var.database_instance_name
  random_instance_name = true
  project_id           = var.project_id

  deletion_protection = false
  backup_configuration = {
    enabled                        = true
    transaction_log_retention_days = 7
    retained_backups               = 7
    binary_log_enabled             = false
    location                       = null
    retention_unit                 = null
    start_time                     = null
  }

  database_version  = "MYSQL_8_0"
  region            = var.region
  zone              = var.zones[0]
  tier              = local.config.db_tier
  availability_type = null

  database_flags = [
    {
      name  = "cloudsql_iam_authentication"
      value = "on"
    },
  ]

  vpc_network = module.network.network_self_link

  additional_users = [
    {
      name            = "app"
      password        = module.wordpress_db_password.secret_data
      host            = "cloudsqlproxy~%"
      type            = "BUILT_IN"
      random_password = false
    },

  ]



  assign_public_ip   = false
  allocated_ip_range = module.network.private_ip_address_name

  // Explicit dependency on service networking connection for proper destroy order
  // This ensures Cloud SQL is destroyed BEFORE the service networking connection
  depends_on = [
    module.bootstrap,
    module.network,
    module.wordpress_db_password
  ]
}

# Service Account Key for WP-Stateless
resource "google_service_account_key" "wordpress_sa_key" {
  service_account_id = module.wordpress_cloudrun.service_account_email
}

# Store service account key in Secret Manager
module "wordpress_sa_key_secret" {
  source = "./modules/secret_manager"

  project_id               = var.project_id
  secret_id                = "wordpress-sa-key"
  secret_data              = base64decode(google_service_account_key.wordpress_sa_key.private_key)
  generate_random_password = false

  # Multi-region replication for high availability
  replication_locations = ["us-central1", "us-east1"]

  labels = merge(var.labels, {
    purpose = "service-account-key"
  })

  depends_on = [module.bootstrap]
}

# Media Storage Bucket
module "media_storage" {
  source = "./modules/storage"

  project_id    = var.project_id
  bucket_name   = "${var.project_id}-media"
  name_prefix   = ""
  force_destroy = true
  location      = var.region

  # Allow public access for media files
  public_access_prevention = "inherited"

  # CORS for WordPress media uploads
  cors_config = {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["Content-Type", "Content-Length"]
    max_age_seconds = 3600
  }

  # IAM: Public can read objects (service account permissions granted separately to avoid circular dependency)
  iam_members = [
    {
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }
  ]

  # Lifecycle rule: delete old versions after 30 days
  lifecycle_rules = [
    {
      action = {
        type = "Delete"
      }
      condition = {
        days_since_noncurrent_time = 30
      }
    }
  ]

  versioning_enabled = true
  enable_cdn         = var.enable_cdn_for_media

  labels = merge(var.labels, {
    purpose = "media-storage"
  })

  depends_on = [module.bootstrap]
}

# Cloud Run Service with WordPress and Cloud SQL Proxy sidecar
module "wordpress_cloudrun" {
  source = "./modules/cloud-run"

  project_id          = var.project_id
  region              = var.region
  name_prefix         = var.name_prefix
  service_name        = "wordpress"
  vpc_network_name    = module.network.network_id
  vpc_subnetwork_name = module.network.subnets_names[0]
  min_instances       = local.config.min_instances
  max_instances       = local.config.max_instances

  # Multi-container configuration
  containers = [
    {
      name                 = "wordpress"
      image                = var.service_image_tag == null ? "wordpress:latest" : "${module.bootstrap.docker_image_prefix}/custom-wp:${var.service_image_tag}"
      cpu_limit            = local.config.cpu_limit
      memory_limit         = local.config.memory_limit
      container_port       = 80
      port_name            = "http1"
      cpu_always_allocated = false
      startup_cpu_boost    = true

      env_vars = {
        WORDPRESS_DB_HOST      = "127.0.0.1:3306"
        WORDPRESS_DB_USER      = "app"
        WORDPRESS_DB_NAME      = "default"
        WORDPRESS_URL          = local.wordpress_url
        ENVIRONMENT            = "production"
        STATELESS_MEDIA_BUCKET = module.media_storage.bucket_name
      }

      # Database password from Secret Manager
      secrets = {
        WORDPRESS_DB_PASSWORD = {
          secret_name = module.wordpress_db_password.secret_id
          version     = "latest"
        }
        WORDPRESS_ADMIN_PASSWORD = {
          secret_name = module.wordpress_admin_password.secret_id
          version     = "latest"
        }
        GOOGLE_APPLICATION_CREDENTIALS_JSON = {
          secret_name = module.wordpress_sa_key_secret.secret_id
          version     = "latest"
        }
      }

      # startup_probe = {
      #   initial_delay_seconds = 10
      #   timeout_seconds       = 3
      #   period_seconds        = 10
      #   failure_threshold     = 3
      #   http_get = {
      #     path = "/"
      #     port = 80
      #   }
      # }

      # liveness_probe = {
      #   initial_delay_seconds = 30
      #   timeout_seconds       = 3
      #   period_seconds        = 30
      #   failure_threshold     = 3
      #   http_get = {
      #     path = "/"
      #     port = 80
      #   }
      # }
    },
    {
      name                 = "cloud-sql-proxy"
      image                = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
      command              = ["/cloud-sql-proxy", "--private-ip", module.mysql_db.instance_connection_name]
      cpu_limit            = "500m"
      memory_limit         = "256Mi"
      cpu_always_allocated = false
      startup_cpu_boost    = false
    }
  ]


  ingress = "INGRESS_TRAFFIC_ALL"

  invoker_members = ["allUsers"]

  labels = merge(var.labels, {
    service = "wordpress"
  })

  # IMPORTANT: Cloud Run Direct VPC egress creates serverless IP reservations
  # that must be destroyed before the network. The depends_on ensures proper
  # destruction order. The network module has a null_resource guard that will
  # check for orphaned IPs during destroy.
  depends_on = [module.mysql_db, module.network]
}

# IAM Binding: Allow Cloud Run to pull images from Artifact Registry (resource-level)
resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  project    = var.project_id
  location   = module.bootstrap.artifact_registry_location
  repository = module.bootstrap.artifact_registry_repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${module.wordpress_cloudrun.service_account_email}"
}

# IAM Binding: Allow Cloud Run to connect to Cloud SQL (project-level - no resource-level alternative)
resource "google_project_iam_member" "cloudrun_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${module.wordpress_cloudrun.service_account_email}"
}

# IAM Binding: Allow Cloud Run to access Secret Manager secrets (resource-level)
resource "google_secret_manager_secret_iam_member" "cloudrun_sql_secret_accessor" {
  secret_id = module.wordpress_db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.wordpress_cloudrun.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "cloudrun_admin_secret_accessor" {
  secret_id = module.wordpress_admin_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.wordpress_cloudrun.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "cloudrun_sa_key_secret_accessor" {
  secret_id = module.wordpress_sa_key_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.wordpress_cloudrun.service_account_email}"
}

# IAM Binding: Allow Cloud Run service account to manage media bucket
resource "google_storage_bucket_iam_member" "wordpress_bucket_admin" {
  bucket = module.media_storage.bucket_name
  role   = "roles/storage.admin"
  member = "serviceAccount:${module.wordpress_cloudrun.service_account_email}"
}
