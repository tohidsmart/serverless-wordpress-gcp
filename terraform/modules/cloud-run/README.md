# Cloud Run Module

## Overview

This module creates a Google Cloud Run v2 service with dedicated service accounts, multi-container support, VPC integration, and resource-level IAM bindings. Designed for production workloads with security and scalability in mind.

## Features

- ✅ Dedicated service account per Cloud Run service (least privilege)
- ✅ Multi-container support (sidecar pattern)
- ✅ VPC Direct VPC Egress (no VPC connector needed)
- ✅ Environment variables and Secret Manager integration
- ✅ Resource-level IAM bindings (not project-level)
- ✅ Health probes (startup, liveness)
- ✅ Traffic splitting for blue/green deployments
- ✅ CPU allocation and startup boost configuration

## Required IAM Roles/Permissions

### For the User/Service Account Running Terraform

To create and manage resources in this module, the following roles are required:

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/run.admin` | Create and manage Cloud Run services | Project |
| `roles/iam.serviceAccountAdmin` | Create dedicated service accounts | Project |
| `roles/iam.serviceAccountUser` | Assign service accounts to Cloud Run | Project |

**Minimum Required Permissions:**
```
run.services.create
run.services.get
run.services.update
run.services.delete
run.services.setIamPolicy
iam.serviceAccounts.create
iam.serviceAccounts.get
iam.serviceAccounts.actAs
```

### Service Account Created by This Module

This module creates a dedicated service account for each Cloud Run service:
- **Name**: `{name_prefix}-{service_name}-sa@{project_id}.iam.gserviceaccount.com`
- **Purpose**: Run the Cloud Run service containers
- **Default Permissions**: None (follows least privilege - grant permissions externally)

### Required IAM Bindings (Granted Outside This Module)

The Cloud Run service account needs these permissions (grant in root module):

| Permission | Resource | Purpose | Example |
|------------|----------|---------|---------|
| `roles/artifactregistry.reader` | Artifact Registry | Pull container images | See terraform/main.tf:386 |
| `roles/cloudsql.client` | Project | Connect to Cloud SQL via proxy | See terraform/main.tf:395 |
| `roles/secretmanager.secretAccessor` | Secrets | Read secrets at runtime | See terraform/main.tf:402-418 |
| `roles/storage.admin` or `storage.objectAdmin` | Storage Bucket | Read/write media files | See terraform/main.tf:421 |

## Usage

### Basic Single Container

```hcl
module "app_cloudrun" {
  source = "./modules/cloud-run"

  project_id          = var.project_id
  region              = var.region
  name_prefix         = "myapp"
  service_name        = "api"
  vpc_network_name    = module.network.network_id
  vpc_subnetwork_name = module.network.subnets_names[0]

  containers = [
    {
      name         = "app"
      image        = "gcr.io/my-project/my-app:latest"
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
      container_port = 8080

      env_vars = {
        NODE_ENV = "production"
        PORT     = "8080"
      }

      secrets = {
        DATABASE_URL = {
          secret_name = module.db_secret.secret_id
          version     = "latest"
        }
      }
    }
  ]

  min_instances = 0
  max_instances = 10

  invoker_members = ["allUsers"]

  labels = {
    environment = "production"
  }
}
```

### Multi-Container (WordPress + Cloud SQL Proxy)

```hcl
module "wordpress_cloudrun" {
  source = "./modules/cloud-run"

  project_id          = var.project_id
  region              = var.region
  name_prefix         = "cms"
  service_name        = "wordpress"
  vpc_network_name    = module.network.network_id
  vpc_subnetwork_name = module.network.subnets_names[0]

  containers = [
    {
      name         = "wordpress"
      image        = "europe-west1-docker.pkg.dev/project/repo/wordpress:1.0.0"
      cpu_limit    = "2000m"
      memory_limit = "1Gi"
      container_port = 80
      
      cpu_always_allocated = false
      startup_cpu_boost    = true

      env_vars = {
        WORDPRESS_DB_HOST = "127.0.0.1:3306"
        WORDPRESS_DB_NAME = "wordpress"
      }

      secrets = {
        WORDPRESS_DB_PASSWORD = {
          secret_name = module.db_password.secret_id
          version     = "latest"
        }
      }
    },
    {
      name         = "cloud-sql-proxy"
      image        = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
      command      = ["/cloud-sql-proxy", "--private-ip", "project:region:instance"]
      cpu_limit    = "500m"
      memory_limit = "256Mi"
    }
  ]

  min_instances = 0
  max_instances = 5
  timeout       = "300s"

  invoker_members = ["allUsers"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| region | GCP region for Cloud Run | `string` | n/a | yes |
| name_prefix | Prefix for resource names | `string` | `""` | no |
| service_name | Cloud Run service name | `string` | n/a | yes |
| labels | Labels to apply | `map(string)` | `{}` | no |
| deletion_protection | Enable deletion protection | `bool` | `false` | no |
| vpc_network_name | VPC network name for Direct VPC Egress | `string` | n/a | yes |
| vpc_subnetwork_name | VPC subnet name | `string` | `""` | no |
| containers | List of container configurations | `list(object)` | n/a | yes |
| timeout | Max request timeout (max 3600s) | `string` | `"300s"` | no |
| min_instances | Minimum instances | `number` | `0` | no |
| max_instances | Maximum instances | `number` | `10` | no |
| vpc_egress_mode | VPC egress mode | `string` | `"PRIVATE_RANGES_ONLY"` | no |
| ingress | Ingress settings | `string` | `"INGRESS_TRAFFIC_ALL"` | no |
| traffic | Traffic configuration | `list(object)` | Latest 100% | no |
| invoker_members | Members who can invoke service | `set(string)` | `[]` | no |

### Container Object Schema

```hcl
{
  name                 = string                    # Container name
  image                = string                    # Full image path
  container_port       = optional(number)          # Exposed port (default: no port)
  port_name            = optional(string, "http1") # Port protocol
  cpu_limit            = optional(string, "1000m") # CPU limit
  memory_limit         = optional(string, "512Mi") # Memory limit
  cpu_always_allocated = optional(bool, false)     # Keep CPU allocated when idle
  startup_cpu_boost    = optional(bool, false)     # Extra CPU during startup
  command              = optional(list(string))    # Override entrypoint
  env_vars             = optional(map(string), {}) # Environment variables
  secrets              = optional(map(object({     # Secret Manager secrets
    secret_name = string
    version     = string
  })), {})
  startup_probe        = optional(object({...}))   # Startup health probe
  liveness_probe       = optional(object({...}))   # Liveness health probe
}
```

## Outputs

| Name | Description |
|------|-------------|
| service_name | Cloud Run service name |
| service_url | Public URL of the service |
| service_id | Full resource ID |
| service_location | Deployment region |
| service_account_email | Service account email (use for IAM bindings) |
| service_account_id | Service account ID |
| service_account_name | Service account name |
| latest_revision | Latest ready revision name |
| terminal_condition | Service terminal condition |

## Important Notes

### VPC Direct VPC Egress
- This module uses Direct VPC Egress (no VPC Access Connector needed)
- Egress mode `PRIVATE_RANGES_ONLY` means traffic to private IPs goes through VPC
- Public internet traffic still goes through Cloud Run's default path
- Allows Cloud Run to connect to Cloud SQL private IP via sidecar proxy

### Security Best Practices
1. **Service Account**: Dedicated per service (least privilege)
2. **IAM Bindings**: Grant permissions at resource level, not project level
3. **Secrets**: Use Secret Manager, never environment variables for sensitive data
4. **Ingress**: Restrict to `INGRESS_TRAFFIC_INTERNAL_ONLY` for internal services
5. **Invokers**: Use specific service accounts instead of `allUsers` when possible

### Multi-Container Pattern
- First container is the main application (receives HTTP traffic)
- Additional containers are sidecars (e.g., Cloud SQL Proxy, logging agents)
- Containers share network namespace (localhost communication)
- Only the first container should expose a port

### Cost Optimization
- Set `min_instances = 0` for development (scale to zero)
- Set `cpu_always_allocated = false` to reduce idle costs
- Use `startup_cpu_boost = true` for faster cold starts
- Right-size CPU/memory limits to avoid over-provisioning

## Examples

See the root module (terraform/main.tf:291-383) for a complete WordPress + Cloud SQL Proxy example.

## License

Apache 2.0 - See LICENSE file for details
