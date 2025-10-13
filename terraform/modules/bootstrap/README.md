# Bootstrap Module

This module sets up the foundational resources for a GCP project to host CMS workloads (WordPress, etc.) on Cloud Run.

## Features

- ✅ Enables required GCP APIs (optional and configurable)
- ✅ Creates Terraform service account for CI/CD
- ✅ Creates Artifact Registry for Docker images
- ✅ Configures IAM bindings
- ✅ Resource-level IAM for least privilege

## Prerequisites

Before running this module, ensure the following prerequisites are met:

### 1. GCP Project
- An existing GCP project (this module does not create the project)
- Project ID available

### 2. Authentication & Permissions
The user or service account running Terraform must have one of:
- **Option A**: `roles/owner` on the project (not recommended for production)
- **Option B**: Combination of these roles (recommended):
  - `roles/serviceusage.serviceUsageAdmin` (to enable APIs)
  - `roles/iam.serviceAccountAdmin` (to create service accounts)
  - `roles/iam.securityAdmin` (to grant IAM roles)
  - `roles/artifactregistry.admin` (to create artifact registry)
  - `roles/resourcemanager.projectIamAdmin` (to set project-level IAM)

### 3. Initial APIs (Manual Enablement Required)
These APIs **must be manually enabled** before running the module (chicken-and-egg problem):
```bash
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable iam.googleapis.com
```

Without these APIs enabled, Terraform cannot enable additional APIs or create service accounts.

### 4. Terraform Version
- Terraform >= 1.5
- Google Provider >= 5.0, < 7.0

## Usage

### Basic Usage

```hcl
module "bootstrap" {
  source = "./modules/bootstrap"

  project_id  = "my-project-id"
  region      = "europe-west1"
  name_prefix = "cms"

  # Enable required APIs
  enable_apis = true
  required_apis = [
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
  ]

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }
}
```

### Usage with APIs Already Enabled

If your project already has APIs enabled (or they're managed elsewhere):

```hcl
module "bootstrap" {
  source = "./modules/bootstrap"

  project_id  = "my-project-id"
  region      = "europe-west1"
  name_prefix = "cms"

  # Skip API management
  enable_apis = false

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }
}
```


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| region | Default GCP region (use EU for GDPR) | `string` | `"europe-west1"` | no |
| name_prefix | Prefix for resource names | `string` | `"cms"` | no |
| artifact_registry_name | Artifact Registry repository name | `string` | `"docker-images"` | no |
| labels | Labels to apply to resources | `map(string)` | `{"managed_by": "terraform", "purpose": "cms-platform"}` | no |
| enable_apis | Whether to enable GCP APIs | `bool` | `true` | no |
| required_apis | List of GCP APIs to enable | `set(string)` | `[]` | yes* |

\*Required when `enable_apis = true` (validated - must provide at least one API)

## Outputs

| Name | Description |
|------|-------------|
| project_id | GCP project ID |
| region | Default region |
| terraform_service_account_email | Email of Terraform service account |
| artifact_registry_repository | Artifact Registry repository name |
| artifact_registry_location | Artifact Registry location |
| docker_image_prefix | Docker image prefix for pushing images (format: `{region}-docker.pkg.dev/{project}/{repo}`) |

## Resources Created

### Service Accounts

- **Name**: `{name_prefix}-terraform@{project_id}.iam.gserviceaccount.com`
- **Purpose**: Used for Terraform deployments (manual or via CI/CD)
- **Permissions**:
  - `roles/editor` (project-level) - Broad permissions for resource management
  - `roles/iam.securityAdmin` (project-level) - IAM management
  - `roles/artifactregistry.writer` (resource-level) - Push Docker images to Artifact Registry

### Artifact Registry
- **Name**: `{artifact_registry_name}` (default: `docker-images`)
- **Format**: Docker
- **Purpose**: Store container images for deployment

### API Management (Optional)
- Enables specified APIs via `required_apis` variable
- Only created if `enable_apis = true`
- APIs are **not** disabled on resource destruction (`disable_on_destroy = false`)

## Post-Bootstrap Steps

After running this module:

1. **Push Docker Images**: Use the `docker_image_prefix` output to push your container images
   ```bash
   docker tag my-image:latest <docker_image_prefix>/my-image:latest
   docker push <docker_image_prefix>/my-image:latest
   ```

2. **Service Account Authentication** (for CI/CD):
   - Generate service account key (if needed for CI/CD pipelines)
   - Store securely in your CI/CD secrets
   - Use for Terraform authentication in automated deployments

## Security Considerations

1. **Least Privilege**: Service accounts should follow least privilege principle
   - Consider using custom roles instead of `roles/editor` for production
   - Grant resource-level permissions where possible
2. **Service Account Keys**:
   - Avoid creating service account keys when possible
   - Rotate keys regularly if used
   - Store keys securely (never commit to version control)
3. **API Security**: APIs are not disabled on destroy to prevent accidental data loss
4. **Artifact Registry**:
   - Enable vulnerability scanning for container images
   - Implement image retention policies to manage storage costs

## GDPR Compliance

- Default region: `europe-west1` (Belgium, EU)
- All resources support EU data residency
- Audit logging enabled via API enablement
- Service accounts support identity-based access control

## Examples

See `/terraform/examples/bootstrap/` for complete usage examples.

## License

Apache 2.0 - See LICENSE file for details
