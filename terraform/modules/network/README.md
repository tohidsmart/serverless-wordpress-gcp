# Network Module

This module creates a complete networking setup for GCP, including VPC, Cloud NAT, VPC Access Connector for Cloud Run, and Private Service Connection for Cloud SQL.

## Features

- ✅ VPC network with custom subnets (using Google's official network module)
- ✅ Cloud Router and Cloud NAT for outbound internet access
- ✅ Private Service Connection for Cloud SQL private IP
- ✅ Configurable routing mode (REGIONAL or GLOBAL)
- ✅ All components are optional and can be enabled/disabled

## Required IAM Roles/Permissions

### For the User/Service Account Running Terraform

To create and manage resources in this module, the following roles are required:

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/compute.networkAdmin` | Create and manage VPC, subnets, routers, NAT | Project |
| `roles/compute.securityAdmin` | Manage firewall rules | Project |
| `roles/servicenetworking.networksAdmin` | Create Private Service Connection for Cloud SQL | Project |

**Minimum Required Permissions:**
```
compute.networks.create
compute.networks.get
compute.networks.update
compute.networks.delete
compute.subnetworks.create
compute.subnetworks.get
compute.subnetworks.update
compute.routers.create
compute.routers.get
compute.routers.update
compute.addresses.create
compute.addresses.get
servicenetworking.services.addPeering
```

### Service Accounts/Resources That Need Network Access

Other modules that use this network will need:
- **Cloud Run**: Requires VPC network for egress to private resources
- **Cloud SQL**: Requires Private Service Connection for private IP addressing

## Architecture

This module composes Google's official network module with additional networking resources:
- **VPC Module**: `terraform-google-modules/network/google` (~> 9.0)
- **Cloud Router + NAT**: For egress traffic from private resources
- **Private Service Connection**: For Cloud SQL to use private IP addresses

## Usage

### Basic Usage

```hcl
module "network" {
  source = "./modules/network"

  project_id  = "my-project-id"
  region      = "europe-west1"
  name_prefix = "cms"

  subnet_cidr = "10.0.0.0/24"
}
```

### Advanced Usage with Custom Configuration

```hcl
module "network" {
  source = "./modules/network"

  project_id  = "my-project-id"
  region      = "europe-west1"
  name_prefix = "cms"

  # VPC configuration
  routing_mode = "GLOBAL"
  subnet_cidr  = "10.0.0.0/24"

  # Cloud NAT
  enable_nat = true
  nat_log_config = {
    enable = true
    filter = "ALL"  # or "ERRORS_ONLY"
  }

  # Private Service Connection for Cloud SQL
  enable_private_service_connection = true
  private_ip_prefix_length          = 20
}
```

### Minimal Setup (VPC Only)

```hcl
module "network" {
  source = "./modules/network"

  project_id  = "my-project-id"
  region      = "europe-west1"
  name_prefix = "cms"

  # Disable optional components
  enable_nat                        = false
  enable_private_service_connection = false
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| region | Default GCP region | `string` | n/a | yes |
| name_prefix | Prefix for resource names | `string` | n/a | yes |
| routing_mode | Network routing mode (REGIONAL or GLOBAL) | `string` | `"GLOBAL"` | no |
| subnet_cidr | CIDR range for the main subnet | `string` | `"10.0.0.0/24"` | no |
| secondary_ranges | Secondary IP ranges for subnet (e.g., GKE) | `list(object)` | `[]` | no |
| firewall_rules | List of firewall rules | `list(any)` | `[]` | no |
| enable_nat | Enable Cloud NAT | `bool` | `true` | no |
| nat_log_config | Cloud NAT logging config | `object` | `{enable=true, filter="ERRORS_ONLY"}` | no |
| enable_private_service_connection | Enable Private Service Connection | `bool` | `true` | no |
| private_ip_prefix_length | Prefix length for private IP (16-24) | `number` | `20` | no |

## Outputs

| Name | Description |
|------|-------------|
| network_name | Name of the VPC network |
| network_id | ID of the VPC network |
| network_self_link | Self link of the VPC network |
| subnets | Map of subnet details |
| subnets_names | List of subnet names |
| subnets_ips | List of subnet IP ranges |
| subnets_self_links | List of subnet self links |
| router_name | Name of the Cloud Router (if enabled) |
| router_id | ID of the Cloud Router (if enabled) |
| nat_name | Name of the Cloud NAT (if enabled) |
| private_ip_address_name | Name of the private IP address range (if enabled) |
| private_ip_address | Private IP address (if enabled) |
| private_vpc_connection | Private VPC connection network (if enabled) |
| private_vpc_connection_id | Private VPC connection ID - use for explicit depends_on |

## Resources Created

### VPC Network (via Google Module)
- VPC network with custom routing mode
- One or more subnets with private Google access
- Optional secondary IP ranges
- Optional firewall rules

### Cloud Router & NAT (Optional)
- **Cloud Router**: Routes traffic between VPC and internet
- **Cloud NAT**: Provides outbound internet access for resources without external IPs
- **Logging**: Configurable (ERRORS_ONLY or ALL)
- **Use Case**: Allow Cloud Run or Cloud SQL to access external APIs

### Private Service Connection (Optional)
- **Purpose**: Enables Cloud SQL to use private IP addresses
- **Global Address**: Reserved IP range for VPC peering
- **Service Networking Connection**: Establishes peering between VPC and Google services
- **Important**: Must exist before creating Cloud SQL instances with private IP

## Important Notes

### CIDR Planning
- **Subnet CIDR**: Main subnet for your Cloud Run and other resources
- **Private IP Range**: Reserved for Cloud SQL (prefix 16-24, auto-assigned by Google)

Example configuration:
```
subnet_cidr                  = "10.0.0.0/24"   # 10.0.0.0 - 10.0.0.255
private_ip_prefix_length     = 20              # Allocates /20 for Cloud SQL
```

### Performance Considerations
- **NAT Logging**: Use `ERRORS_ONLY` in production to reduce log costs
- **Routing Mode**: Use `GLOBAL` for multi-region setups, `REGIONAL` for single-region

### Cost Optimization
- **Cloud NAT**: Charges apply for data processing and NAT gateway hours (~$0.045/hour + data processing)
- **VPC**: No charge for VPC itself, only for resources using it
- **Private Service Connection**: No additional charge for the peering connection
- Consider disabling NAT if your services don't need outbound internet access

## Examples

See `/terraform/examples/` for complete usage examples.

## License

Apache 2.0 - See LICENSE file for details
