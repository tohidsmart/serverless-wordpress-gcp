# Secret Manager Module

Creates a Google Cloud Secret Manager secret with optional random password generation, EU-only replication for GDPR compliance, and IAM bindings.

## Features

- **Random Password Generation**: Automatically generate secure random passwords
- **GDPR Compliance**: Support for EU-only replication
- **Flexible Secret Data**: Use provided secret or generate random password
- **IAM Management**: Grant access to specific service accounts or users (resource-level)
- **Password Requirements**: Configurable length and character requirements

## Required IAM Roles/Permissions

### For the User/Service Account Running Terraform

To create and manage resources in this module, the following roles are required:

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/secretmanager.admin` | Create and manage secrets | Project |

**Minimum Required Permissions:**
```
secretmanager.secrets.create
secretmanager.secrets.get
secretmanager.secrets.update
secretmanager.secrets.delete
secretmanager.secrets.setIamPolicy
secretmanager.secrets.getIamPolicy
secretmanager.versions.add
secretmanager.versions.access
```

### IAM Bindings for Secret Access

This module supports granting access via the `accessor_members` variable:

| Role | Purpose | Scope |
|------|---------|-------|
| `roles/secretmanager.secretAccessor` | Read secret values at runtime | Resource-level (per secret) |

**Note**: IAM bindings are typically granted in the root module to avoid circular dependencies. See usage examples below.

## Usage

### Option 1: Generate Random Password

```hcl
module "db_password" {
  source = "./modules/secret_manager"

  project_id                = var.project_id
  secret_id                 = "wordpress-db-password"
  generate_random_password  = true
  password_length           = 32
  password_special_chars    = true

  # GDPR: EU-only replication
  replication_locations = ["europe-west1", "europe-west3"]

  labels = {
    environment = "production"
  }
}

# Retrieve the generated password
output "password" {
  value     = module.db_password.generated_password
  sensitive = true
}
```

### Option 2: Provide Your Own Secret

```hcl
module "api_key" {
  source = "./modules/secret_manager"

  project_id  = var.project_id
  secret_id   = "api-key"
  secret_data = "your-api-key-here"

  # Automatic replication (all regions)
  replication_locations = []

  labels = {
    purpose = "api-credentials"
  }
}
```

### Option 3: With IAM Bindings (added separately to avoid circular dependency)

```hcl
module "db_password" {
  source = "./modules/secret_manager"

  project_id               = var.project_id
  secret_id                = "db-password"
  generate_random_password = true

  replication_locations = ["europe-west1"]
  labels = { environment = "prod" }
}

# Grant Cloud Run access
resource "google_secret_manager_secret_iam_member" "cloudrun_access" {
  secret_id = module.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| secret_id | ID of the secret | `string` | n/a | yes |
| secret_data | The secret data (ignored if generate_random_password is true) | `string` | `null` | no |
| generate_random_password | Whether to generate a random password | `bool` | `false` | no |
| password_length | Length of generated password | `number` | `32` | no |
| password_special_chars | Include special characters in password | `bool` | `true` | no |
| replication_locations | List of regions for replication (empty for automatic) | `list(string)` | `[]` | no |
| accessor_members | List of members who can access this secret | `list(string)` | `[]` | no |
| labels | Labels to apply to the secret | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| secret_id | The ID of the secret |
| secret_name | The full resource name of the secret |
| version_name | The full resource name of the secret version |
| version_id | The version ID |
| generated_password | The generated password (sensitive, only if generate_random_password is true) |

## Password Generation Requirements

When `generate_random_password = true`, the password will contain:

- Minimum 2 lowercase letters
- Minimum 2 uppercase letters
- Minimum 2 numbers
- Minimum 2 special characters (if `password_special_chars = true`)
- Allowed special characters: `!@#$%^&*()-_=+[]{}:?`

## GDPR Compliance

For GDPR compliance, specify EU regions in `replication_locations`:

```hcl
replication_locations = ["europe-west1", "europe-west3", "europe-west4"]
```

Available EU regions:
- `europe-west1` (Belgium)
- `europe-west3` (Frankfurt)
- `europe-west4` (Netherlands)
- `europe-north1` (Finland)

## Use with Cloud Run

```hcl
module "cloud_run" {
  containers = [{
    secrets = {
      DB_PASSWORD = {
        secret_name = module.db_password.secret_id
        version     = "latest"
      }
    }
  }]
}

# Grant Cloud Run service account access to the secret
resource "google_secret_manager_secret_iam_member" "cloudrun_access" {
  secret_id = module.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.cloud_run.service_account_email}"
}
```

## Security Considerations

1. **Least Privilege**: Grant `secretAccessor` role only to service accounts that need it
2. **Resource-Level IAM**: Use resource-level bindings (per secret) instead of project-level
3. **Replication**: For GDPR compliance, restrict replication to EU regions only
4. **Versioning**: Secret Manager automatically versions secrets - old versions remain accessible
5. **Audit Logging**: All secret access is logged in Cloud Audit Logs
6. **Never Log Secrets**: Ensure secrets are marked as `sensitive` in Terraform outputs

## Best Practices

- **Random Passwords**: Always use `generate_random_password = true` for database passwords
- **Manual Secrets**: Use `secret_data` for API keys and credentials from external systems
- **Rotation**: Implement secret rotation policies for production systems
- **Access Control**: Review IAM bindings regularly and remove unnecessary access
- **Monitoring**: Set up alerts for unusual secret access patterns

## Cost Considerations

- **Active Secrets**: $0.06 per secret per month
- **Secret Versions**: $0.03 per 10,000 access operations
- **Replication**: No additional charge for multi-region replication
- **Cost Optimization**: Delete old secret versions that are no longer needed

## License

Apache 2.0 - See LICENSE file for details
