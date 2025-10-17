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
  Network Module
  - VPC network with subnets
  - Cloud Router and Cloud NAT
  - Private Service Connection for Cloud SQL
 *****************************************/

# VPC Network using Google's official module
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "${var.name_prefix}-vpc"
  routing_mode = var.routing_mode

  subnets = [
    {
      subnet_name           = "${var.name_prefix}-subnet"
      subnet_ip             = var.subnet_cidr
      subnet_region         = var.region
      subnet_private_access = true
      description           = "Main subnet for Cloud SQL private IP and Cloud Run Direct VPC egress"
    }
  ]

  # Secondary ranges for future use (GKE pods/services, etc.)
  secondary_ranges = {
    "${var.name_prefix}-subnet" = var.secondary_ranges
  }

  # Optional firewall rules
  firewall_rules = var.firewall_rules
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "router" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = module.vpc.network_id
}

# Cloud NAT for outbound internet access from private resources
resource "google_compute_router_nat" "nat" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${var.name_prefix}-nat"
  router  = google_compute_router.router[0].name
  region  = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = var.nat_log_config.enable
    filter = var.nat_log_config.filter
  }
}

# Private IP address range for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  count = var.enable_private_service_connection ? 1 : 0

  project       = var.project_id
  name          = "${var.name_prefix}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_ip_prefix_length
  network       = module.vpc.network_id
  depends_on    = [module.vpc]
}

# Private Service Connection for Cloud SQL private IP
resource "google_service_networking_connection" "private_vpc_connection" {
  count = var.enable_private_service_connection ? 1 : 0

  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]
}
