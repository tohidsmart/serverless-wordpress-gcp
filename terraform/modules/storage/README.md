# Storage Module

## Overview

This module creates Google Cloud Storage buckets with configurable features including versioning, lifecycle management, CORS support, IAM bindings, and optional Cloud CDN integration. Designed for media storage, static assets, and file hosting.

## Features

- ✅ Cloud Storage buckets with uniform bucket-level access
- ✅ Object versioning and lifecycle rules
- ✅ CORS configuration for web applications
- ✅ Flexible IAM bindings (resource-level)
- ✅ Optional Cloud CDN backend bucket
- ✅ Public or private access control
- ✅ Configurable storage classes (STANDARD, NEARLINE, COLDLINE, ARCHIVE)

## Required IAM Roles/Permissions

### For the User/Service Account Running Terraform

To create and manage resources in this module, the following roles are required:

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/storage.admin` | Create and manage storage buckets | Project |
| `roles/compute.loadBalancerAdmin` | Create CDN backend buckets (if enabled) | Project |

**Minimum Required Permissions:**
```
storage.buckets.create
storage.buckets.get
storage.buckets.update
storage.buckets.delete
storage.buckets.setIamPolicy
storage.buckets.getIamPolicy
compute.backendBuckets.create     (if CDN enabled)
compute.backendBuckets.get        (if CDN enabled)
```

### IAM Bindings for Bucket Access

Common IAM roles for bucket access (configured via `iam_members` variable):

| Role | Purpose | Use Case |
|------|---------|----------|
| `roles/storage.objectViewer` | Read objects | Public read access for media files |
| `roles/storage.objectAdmin` | Full object control | Service account managing media uploads |
| `roles/storage.admin` | Full bucket control | Administrative access |
| `allUsers` | Public internet access | Public website assets, CDN content |

## Usage

### Basic Storage Bucket

```hcl
module "app_storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  bucket_name = "app-assets"
  name_prefix = ""
  location    = "europe-west1"

  storage_class = "STANDARD"
  versioning_enabled = false

  public_access_prevention = "enforced"  # Private bucket

  labels = {
    purpose = "application-assets"
  }
}
```

### Public Media Bucket with CDN

```hcl
module "media_storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  bucket_name = "${var.project_id}-media"
  name_prefix = ""
  location    = var.region

  # Allow public access
  public_access_prevention = "inherited"

  # CORS for WordPress media uploads
  cors_config = {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["Content-Type", "Content-Length"]
    max_age_seconds = 3600
  }

  # Public read access
  iam_members = [
    {
      role   = "roles/storage.objectViewer"
      member = "allUsers"
    }
  ]

  # Lifecycle: delete old versions after 30 days
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
  enable_cdn         = true

  # CDN configuration
  cdn_cache_mode   = "CACHE_ALL_STATIC"
  cdn_default_ttl  = 3600    # 1 hour
  cdn_max_ttl      = 86400   # 24 hours

  labels = {
    purpose = "media-storage"
  }
}
```

### Private Bucket with Service Account Access

```hcl
module "private_storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  bucket_name = "app-data"
  location    = "europe-west1"

  # Enforce private access
  public_access_prevention = "enforced"

  # Grant access to specific service accounts
  iam_members = [
    {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:${module.cloud_run.service_account_email}"
    }
  ]

  # Lifecycle: move to NEARLINE after 90 days
  lifecycle_rules = [
    {
      action = {
        type          = "SetStorageClass"
        storage_class = "NEARLINE"
      }
      condition = {
        age = 90
      }
    }
  ]

  labels = {
    purpose = "application-data"
    tier    = "archived"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| bucket_name | Bucket name (prefixed if name_prefix set) | `string` | n/a | yes |
| name_prefix | Prefix for bucket name | `string` | `""` | no |
| location | Bucket location (region or multi-region) | `string` | `"US"` | no |
| storage_class | Storage class | `string` | `"STANDARD"` | no |
| uniform_bucket_level_access | Enable uniform bucket-level access | `bool` | `true` | no |
| public_access_prevention | Public access prevention (inherited/enforced) | `string` | `"enforced"` | no |
| versioning_enabled | Enable object versioning | `bool` | `false` | no |
| force_destroy | Allow bucket deletion with objects | `bool` | `false` | no |
| labels | Labels to apply | `map(string)` | `{}` | no |
| lifecycle_rules | Lifecycle rules | `list(object)` | `[]` | no |
| cors_config | CORS configuration | `object` | `null` | no |
| iam_members | IAM member bindings | `list(object)` | `[]` | no |
| enable_cdn | Enable Cloud CDN backend | `bool` | `false` | no |
| cdn_cache_mode | CDN cache mode | `string` | `"CACHE_ALL_STATIC"` | no |
| cdn_client_ttl | CDN client TTL (seconds) | `number` | `3600` | no |
| cdn_default_ttl | CDN default TTL (seconds) | `number` | `3600` | no |
| cdn_max_ttl | CDN max TTL (seconds) | `number` | `86400` | no |
| cdn_negative_caching | Enable CDN negative caching | `bool` | `false` | no |
| cdn_serve_while_stale | Serve stale content (seconds) | `number` | `0` | no |

### Storage Classes

| Class | Use Case | Retrieval Time | Cost (per GB/month) |
|-------|----------|----------------|---------------------|
| STANDARD | Hot data, frequent access | Immediate | $0.020 (regional) |
| NEARLINE | Accessed <1/month | Immediate | $0.010 |
| COLDLINE | Accessed <1/quarter | Immediate | $0.004 |
| ARCHIVE | Accessed <1/year | Immediate | $0.0012 |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Storage bucket name |
| bucket_url | Bucket URL (gs://) |
| bucket_self_link | Bucket self link |
| cdn_backend_id | CDN backend ID (if enabled) |
| cdn_backend_self_link | CDN backend self link (if enabled) |

## Important Notes

### Public vs Private Access

- **`public_access_prevention = "enforced"`**: Bucket is private, `allUsers` bindings are blocked
- **`public_access_prevention = "inherited"`**: Allows public access if IAM bindings permit

### Lifecycle Rules Examples

**Delete objects older than 365 days:**
```hcl
lifecycle_rules = [
  {
    action = { type = "Delete" }
    condition = { age = 365 }
  }
]
```

**Move to COLDLINE after 180 days:**
```hcl
lifecycle_rules = [
  {
    action = {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition = { age = 180 }
  }
]
```

**Delete non-current versions after 30 days:**
```hcl
lifecycle_rules = [
  {
    action = { type = "Delete" }
    condition = { days_since_noncurrent_time = 30 }
  }
]
```

### CORS Configuration

Required for browser-based uploads (e.g., WordPress media library):
```hcl
cors_config = {
  origin          = ["https://example.com"]  # Your domain
  method          = ["GET", "HEAD", "PUT", "POST"]
  response_header = ["Content-Type"]
  max_age_seconds = 3600
}
```

### CDN Integration

When `enable_cdn = true`:
- Creates a `google_compute_backend_bucket` resource
- Enables Cloud CDN caching
- Requires global load balancer to serve content (not created by this module)
- Additional cost: Data egress through CDN (~$0.08-0.20/GB depending on location)

### Security Considerations

1. **Uniform Bucket-Level Access**: Always use `uniform_bucket_level_access = true` (default)
2. **Public Access**: Only set `public_access_prevention = "inherited"` for truly public content
3. **IAM Bindings**: Grant least privilege - use `objectViewer` instead of `admin` when possible
4. **Versioning**: Enable for important data to protect against accidental deletion
5. **Force Destroy**: Keep `force_destroy = false` in production to prevent data loss

### Cost Optimization

- **Storage Class**: Use NEARLINE/COLDLINE for infrequently accessed data
- **Lifecycle Rules**: Automatically transition or delete old objects
- **CDN**: Reduces egress costs but adds CDN processing fees
- **Versioning**: Increases storage costs (old versions count toward storage)
- **Location**: Regional storage is cheaper than multi-region

**Example Costs** (US region, 100GB):
- STANDARD storage: $2/month
- NEARLINE storage: $1/month
- COLDLINE storage: $0.40/month
- Egress (first 1TB): Free (within same region to GCP services)

## Examples

See the root module (terraform/main.tf:241-288) for a complete media storage example with WordPress integration.

## License

Apache 2.0 - See LICENSE file for details
