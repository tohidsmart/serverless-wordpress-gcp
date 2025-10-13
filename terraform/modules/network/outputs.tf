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

# VPC Outputs
output "network_name" {
  description = "Name of the VPC network"
  value       = module.vpc.network_name
}

output "network_id" {
  description = "ID of the VPC network"
  value       = module.vpc.network_id
}

output "network_self_link" {
  description = "Self link of the VPC network"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "Map of subnet details"
  value       = module.vpc.subnets
}

output "subnets_names" {
  description = "List of subnet names"
  value       = module.vpc.subnets_names
}

output "subnets_ips" {
  description = "List of subnet IP ranges"
  value       = module.vpc.subnets_ips
}

output "subnets_self_links" {
  description = "List of subnet self links"
  value       = module.vpc.subnets_self_links
}

# Cloud Router Outputs
output "router_name" {
  description = "Name of the Cloud Router (if NAT is enabled)"
  value       = var.enable_nat ? google_compute_router.router[0].name : null
}

output "router_id" {
  description = "ID of the Cloud Router (if NAT is enabled)"
  value       = var.enable_nat ? google_compute_router.router[0].id : null
}

# Cloud NAT Outputs
output "nat_name" {
  description = "Name of the Cloud NAT (if enabled)"
  value       = var.enable_nat ? google_compute_router_nat.nat[0].name : null
}

# Private Service Connection Outputs
output "private_ip_address_name" {
  description = "Name of the private IP address range (if private service connection is enabled)"
  value       = var.enable_private_service_connection ? google_compute_global_address.private_ip_address[0].name : null
}

output "private_ip_address" {
  description = "Private IP address (if private service connection is enabled)"
  value       = var.enable_private_service_connection ? google_compute_global_address.private_ip_address[0].address : null
}

output "private_vpc_connection" {
  description = "Private VPC connection network (if enabled)"
  value       = var.enable_private_service_connection ? google_service_networking_connection.private_vpc_connection[0].network : null
}

output "private_vpc_connection_id" {
  description = "Private VPC connection ID - use for explicit depends_on to ensure proper destroy order"
  value       = var.enable_private_service_connection ? google_service_networking_connection.private_vpc_connection[0].id : null
}
