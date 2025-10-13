# Cloud Run IAM Bindings Guide

This module follows the **separation of concerns** principle - it manages Cloud Run resources but does NOT create project-level IAM bindings. The calling module is responsible for granting necessary permissions to the service account.

## Why IAM Bindings Are Outside the Module

### 1. Avoids Circular Dependencies

The primary reason is to prevent Terraform circular dependencies:

**The Problem:**
- Cloud Run depends on Cloud SQL outputs (e.g., `instance_connection_name` for Cloud SQL Proxy)
- If Cloud SQL module created IAM bindings, it would depend on Cloud Run outputs (e.g., `service_account_email`)
- This creates: `Cloud Run → Cloud SQL → Cloud Run` (circular dependency ❌)

**The Solution:**
```hcl
# 1. Cloud SQL module (no dependencies)
module "cloud_sql" { }

# 2. Cloud Run module (depends on Cloud SQL outputs)
module "cloud_run" {
  containers = [{
    command = ["/cloud-sql-proxy", module.cloud_sql.instance_connection_name]
  }]
}

# 3. IAM binding in root module (depends on both, but no cycle ✅)
resource "google_project_iam_member" "cloudsql_access" {
  member = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

### 2. Other Benefits

- **Single Responsibility**: Cloud Run module manages Cloud Run, not project IAM
- **Flexibility**: Different deployments need different permissions
- **Security**: Explicit permission grants in root module are more auditable
- **Reusability**: Module doesn't make assumptions about required permissions

## Service Account Output

The module outputs the service account email for IAM binding:

```hcl
output "service_account_email" {
  description = "The email of the service account used by Cloud Run"
  value       = google_service_account.cloud_run.email
}
```

## Common IAM Bindings

### 1. Artifact Registry (Pull Container Images)

**Required when:** Using custom container images from Artifact Registry

```hcl
module "cloud_run" {
  source = "./modules/cloud-run"
  # ... other config
}

resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

### 2. Secret Manager (Access Secrets)

**Required when:** Using secrets in environment variables

```hcl
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

**Or grant access to specific secrets:**

```hcl
resource "google_secret_manager_secret_iam_member" "secret_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

### 3. Cloud SQL (Database Access)

**Required when:** Connecting to Cloud SQL via Cloud SQL Proxy

```hcl
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

### 4. Cloud Storage (Read/Write Files)

**Required when:** Accessing Cloud Storage buckets

```hcl
# Read-only access
resource "google_storage_bucket_iam_member" "storage_reader" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.cloud_run.service_account_email}"
}

# Read-write access
resource "google_storage_bucket_iam_member" "storage_writer" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

### 5. Cloud Logging & Monitoring

**Required when:** Writing logs and metrics (usually granted by default, but explicit is better)

```hcl
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${module.cloud_run.service_account_email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

## Complete Example: WordPress on Cloud Run

This example shows the proper dependency order and IAM bindings:

```hcl
# 1. Create Cloud SQL first (no dependencies)
module "mysql_db" {
  source = "./modules/cloud-sql"
  # ... configuration
}

# 2. Create Cloud Run (depends on Cloud SQL output)
module "wordpress_cloud_run" {
  source       = "./modules/cloud-run"
  project_id   = var.project_id
  region       = var.region
  service_name = "wordpress"

  containers = [{
    name  = "wordpress"
    image = "australia-southeast1-docker.pkg.dev/${var.project_id}/docker-images/wordpress:latest"

    # Depends on Cloud SQL output
    command = [
      "/cloud-sql-proxy",
      "--private-ip",
      module.mysql_db.instance_connection_name
    ]

    secrets = {
      WORDPRESS_DB_PASSWORD = {
        secret_name = "wordpress-db-password"
        version     = "latest"
      }
    }
  }]
}

# 3. Create IAM bindings (depends on both modules)

# IAM: Pull images from Artifact Registry
resource "google_project_iam_member" "wordpress_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${module.wordpress_cloud_run.service_account_email}"
}

# IAM: Access database secrets
resource "google_project_iam_member" "wordpress_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.wordpress_cloud_run.service_account_email}"
}

# IAM: Connect to Cloud SQL (breaks circular dependency)
resource "google_project_iam_member" "wordpress_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${module.wordpress_cloud_run.service_account_email}"
}

# IAM: Access Cloud Storage for uploads
resource "google_storage_bucket_iam_member" "wordpress_storage" {
  bucket = google_storage_bucket.wordpress_uploads.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.wordpress_cloud_run.service_account_email}"
}

# IAM: Write logs
resource "google_project_iam_member" "wordpress_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${module.wordpress_cloud_run.service_account_email}"
}
```

**Dependency Graph:**
```
Cloud SQL → (no dependencies)
    ↓
Cloud Run → (depends on Cloud SQL outputs)
    ↓
IAM Bindings → (depends on both Cloud SQL & Cloud Run outputs)
```

## Best Practices

1. **Principle of Least Privilege**: Only grant permissions that are actually needed
2. **Resource-level IAM over Project-level**: Use bucket/secret-specific bindings when possible
3. **Explicit over Implicit**: Don't rely on default service account permissions
4. **Document Requirements**: Comment why each IAM binding is needed
5. **Separate Concerns**: Keep IAM bindings in the root module, not nested modules

## Migration from Old Module

If your module previously had `cloudsql_instances` variable:

**Old way (had circular dependency risk):**
```hcl
module "cloud_run" {
  cloudsql_instances = ["project:region:instance"]
}
```

**New way (no circular dependency):**
```hcl
# Cloud Run module doesn't handle IAM
module "cloud_run" {
  # No cloudsql_instances variable
}

# IAM binding in root module
resource "google_project_iam_member" "cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

## Why This Pattern Matters

**Without proper separation**, you could encounter:
```
Error: Cycle: module.cloud_run, module.cloud_sql
```

**With this pattern**, Terraform dependency graph is clean:
- ✅ Cloud SQL created independently
- ✅ Cloud Run uses Cloud SQL outputs
- ✅ IAM bindings use both outputs (no cycle)

This architecture ensures your infrastructure is composable, maintainable, and free of circular dependencies.
