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
  Root Module Outputs
 *****************************************/

# Project Information
output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "Default region"
  value       = var.region
}

# Bootstrap Outputs
output "terraform_service_account_email" {
  description = "Email of the Terraform service account"
  value       = module.bootstrap.terraform_service_account_email
}

output "docker_image_prefix" {
  description = "Docker image prefix for pushing images"
  value       = module.bootstrap.docker_image_prefix
}


# Network Outputs
output "network_name" {
  description = "Name of the VPC network"
  value       = module.network.network_name
}

output "network_id" {
  description = "ID of the VPC network"
  value       = module.network.network_id
}

output "network_self_link" {
  description = "Self link of the VPC network"
  value       = module.network.network_self_link
}

output "subnet_names" {
  description = "Names of the subnets"
  value       = module.network.subnets_names
}

output "subnet_ips" {
  description = "IP ranges of the subnets"
  value       = module.network.subnets_ips
}

output "private_vpc_connection" {
  description = "Private VPC connection for Cloud SQL"
  value       = module.network.private_vpc_connection
}

# Cloud Run Outputs
output "wordpress_url" {
  description = "WordPress Cloud Run service URL (actual)"
  value       = module.wordpress_cloudrun.service_url
}

output "wordpress_configured_url" {
  description = "WordPress configured URL (set in WP_HOME and WP_SITEURL)"
  value       = local.wordpress_url
}

output "wordpress_service_account" {
  description = "WordPress Cloud Run service account email"
  value       = module.wordpress_cloudrun.service_account_email
}

# Database Outputs
output "database_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = module.mysql_db.instance_connection_name
}

output "database_name" {
  description = "Database name"
  value       = "default"
}

output "database_user" {
  description = "Database user"
  value       = "app"
}

# Secret Outputs (sensitive)
output "wordpress_db_password" {
  description = "WordPress database password"
  value       = module.wordpress_db_password.secret_data
  sensitive   = true
}

output "wordpress_admin_password" {
  description = "WordPress admin password"
  value       = module.wordpress_admin_password.secret_data
  sensitive   = true
}

# Storage Outputs
output "media_bucket_name" {
  description = "Media storage bucket name"
  value       = module.media_storage.bucket_name
}

output "media_bucket_url" {
  description = "Media storage bucket URL"
  value       = module.media_storage.bucket_url
}
