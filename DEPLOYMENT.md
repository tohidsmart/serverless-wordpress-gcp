# Deployment Guide

Complete guide to deploying production-ready WordPress on Google Cloud Platform using this repository.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deployment Methods](#deployment-methods)
   - [Quick Deploy (Recommended)](#quick-deploy-recommended)
   - [Manual Step-by-Step Deploy](#manual-step-by-step-deploy)
4. [Post-Deployment](#post-deployment)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Teardown](#teardown)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **gcloud CLI** | Latest | GCP authentication and API calls | [Install Guide](https://cloud.google.com/sdk/docs/install) |
| **Terraform** | 1.5+ | Infrastructure deployment | [Download](https://www.terraform.io/downloads) |
| **Docker** | 20.10+ | Build custom WordPress image | [Get Docker](https://docs.docker.com/get-docker/) |
| **Git** | Any | Clone repository | Usually pre-installed |

### GCP Account Setup

**1. Create GCP Account**
- Sign up at [cloud.google.com](https://cloud.google.com/)
- New users get $300 free credits for 90 days
- **Important:** Must upgrade from free trial to paid account (required for Cloud SQL)

**2. Create or Select a Project**

```bash
# Create new project
gcloud projects create YOUR-PROJECT-ID --name="WordPress Hosting"

# Or list existing projects
gcloud projects list

# Set as default project
gcloud config set project YOUR-PROJECT-ID
```

**3. Enable Billing**
- Navigate to [Billing](https://console.cloud.google.com/billing) in GCP Console
- Link your project to a billing account
- **Why needed:** Cloud SQL and other services require billing enabled

**4. Configure Authentication**

```bash
# Authenticate with your Google account
gcloud auth login

# Set application default credentials (for Terraform)
gcloud auth application-default login

# Verify authentication
gcloud auth list
```

### IAM Permissions Required

Your GCP user account needs these roles:

| Role | Purpose |
|------|---------|
| `roles/owner` | Full project access (simplest for first deployment) |

**OR** these granular roles:

| Role | Purpose |
|------|---------|
| `roles/serviceusage.serviceUsageAdmin` | Enable/disable APIs |
| `roles/storage.admin` | Create state bucket and media bucket |
| `roles/iam.serviceAccountAdmin` | Create service accounts |
| `roles/iam.securityAdmin` | Grant IAM permissions |
| `roles/compute.networkAdmin` | Create VPC, subnets, NAT |
| `roles/run.admin` | Deploy Cloud Run services |
| `roles/cloudsql.admin` | Create Cloud SQL instances |
| `roles/secretmanager.admin` | Create and manage secrets |
| `roles/artifactregistry.admin` | Create container registry |

Check your permissions:
```bash
gcloud projects get-iam-policy YOUR-PROJECT-ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR-EMAIL"
```

---

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/serverless-wordpress-gcp.git
cd serverless-wordpress-gcp
```

### 2. Verify Tools

```bash
# Check gcloud
gcloud --version

# Check Terraform
terraform --version

# Check Docker
docker --version

# Check authentication
gcloud auth list
```

### 3. Review Configuration (Optional)

The deployment uses sensible defaults. If you want to customize:

```bash
# View default variables
cat terraform/variables.tf

# View deployment profile
cat terraform/main.tf | grep -A 10 "profile_config"
```

**Default Configuration:**
- **Region:** `us-central1` (Iowa)
- **Profile:** `tiny` (db-f1-micro, 1 CPU, 512MB RAM)
- **Min instances:** 0 (scales to zero)
- **Max instances:** 3

---

## Deployment Methods

### Quick Deploy (Recommended)

**One command deploys everything:**

```bash
./scripts/end-to-end-deploy.sh YOUR-PROJECT-ID
```

**Optional parameters:**

```bash
# Specify region (default: us-central1)
./scripts/end-to-end-deploy.sh YOUR-PROJECT-ID us-central1

# Specify custom image tag (default: latest)
./scripts/end-to-end-deploy.sh YOUR-PROJECT-ID us-central1 v1.0.0
```

**What this script does:**

1. **Enable Minimum APIs** (~30 seconds)
   - cloudresourcemanager.googleapis.com
   - serviceusage.googleapis.com
   - iam.googleapis.com
   - storage.googleapis.com

2. **Create State Bucket** (~20 seconds)
   - Creates `YOUR-PROJECT-ID-terraform-state` bucket
   - Enables versioning for state recovery
   - Applies lifecycle rules for old versions

3. **Configure Terraform Backend** (~5 seconds)
   - Updates `main.tf` with bucket name
   - Initializes Terraform with remote state

4. **Deploy Infrastructure** (~6-8 minutes)
   - **VPC & Networking:** Subnet, Cloud NAT, Private Service Connection
   - **Database:** Cloud SQL MySQL instance (this is the slowest part)
   - **Secrets:** Random passwords for database and WordPress admin
   - **Cloud Run:** Service with stock WordPress image (temporary)
   - **Storage:** Media bucket with CORS and public access
   - **IAM:** Resource-level permissions

5. **Build & Push Custom Image** (~2-3 minutes)
   - Builds WordPress Docker image with customizations
   - Pushes to Artifact Registry
   - Tagged as specified (default: `latest`)

6. **Update Cloud Run** (~1 minute)
   - Redeploys Cloud Run with custom WordPress image
   - No downtime (blue-green deployment)

**Total time:** ~8-12 minutes

**Success output:**

```
=== Deployment complete ===

WordPress URL: https://cms-wordpress-123456789.us-central1.run.app
```

---

### Manual Step-by-Step Deploy

If you prefer granular control or need to troubleshoot:

#### Step 1: Enable APIs

```bash
gcloud config set project YOUR-PROJECT-ID

gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable storage.googleapis.com
```

#### Step 2: Create Terraform State Bucket

```bash
./scripts/bootstrap-state-bucket.sh YOUR-PROJECT-ID us-central1
```

**What this creates:**
- Bucket: `YOUR-PROJECT-ID-terraform-state`
- Location: Same region as deployment
- Versioning: Enabled
- Lifecycle: Keep 5 versions, delete after 90 days

#### Step 3: Configure Terraform Backend

```bash
# Update main.tf with your bucket name
sed -i.bak 's/bucket = ""/bucket = "YOUR-PROJECT-ID-terraform-state"/' terraform/main.tf

# Or manually edit terraform/main.tf:
# backend "gcs" {
#   bucket = "YOUR-PROJECT-ID-terraform-state"
#   prefix = "wp"
# }
```

#### Step 4: Initialize Terraform

```bash
cd terraform

terraform init
```

**Expected output:**
```
Initializing the backend...
Successfully configured the backend "gcs"!

Initializing provider plugins...
- terraform.io/google ~> 5.0

Terraform has been successfully initialized!
```

#### Step 5: Plan Deployment

```bash
terraform plan -var="project_id=YOUR-PROJECT-ID"
```

**Review the plan:**
- ~40-50 resources to be created
- No resources destroyed (first deployment)
- Check for any errors

#### Step 6: Deploy Infrastructure

```bash
terraform apply -var="project_id=YOUR-PROJECT-ID"
```

Type `yes` when prompted.

**Wait time:** ~6-8 minutes (Cloud SQL creation is the bottleneck)

#### Step 7: Build and Push WordPress Image

```bash
# Get the Artifact Registry URL from Terraform output
DOCKER_REPO=$(terraform output -raw docker_image_prefix)

# Build and push (run from repository root)
cd ..
./scripts/docker-build-push.sh $DOCKER_REPO us-central1 latest
```

#### Step 8: Update Cloud Run with Custom Image

```bash
cd terraform

terraform apply \
  -var="project_id=YOUR-PROJECT-ID" \
  -var="service_image_tag=latest"
```

Type `yes` when prompted.

#### Step 9: Get WordPress URL

```bash
terraform output wordpress_url
```

---

## Post-Deployment

### Access WordPress Admin

**1. Get the WordPress URL:**

```bash
cd terraform
terraform output wordpress_url
```

Example: `https://cms-wordpress-123456789.us-central1.run.app`

**2. Get the Admin Password:**

```bash
# From Terraform
terraform output -raw wordpress_admin_password

# Or from Secret Manager
gcloud secrets versions access latest --secret="wordpress-admin-password"
```

**3. Login:**

- URL: `https://your-url.run.app/wp-admin`
- Username: `admin`
- Password: (from step 2)

### Verify Deployment

**Check Cloud Run Service:**

```bash
gcloud run services describe cms-wordpress \
  --region=us-central1 \
  --format="value(status.url)"
```

**Check Database Connection:**

```bash
gcloud sql instances describe wp-instance-* \
  --format="value(state)"
```

Should show: `RUNNABLE`

**Check Media Bucket:**

```bash
gcloud storage ls gs://YOUR-PROJECT-ID-media/
```

**Test WordPress:**

```bash
# Check homepage
curl -I https://your-url.run.app

# Should return HTTP/2 200
```

### Configure WP-Stateless (Media Storage)

The deployment includes WP-Stateless plugin for storing media in Cloud Storage.

**1. Install Plugin (if not pre-installed):**
- Go to `wp-admin/plugins.php`
- Search for "WP-Stateless"
- Install and activate

**2. Configure Plugin:**

Navigate to Settings > Media > Stateless:

```
Mode: Stateless
Bucket: YOUR-PROJECT-ID-media
Service Account Key: (auto-configured via environment variable)
```

**3. Test Media Upload:**
- Upload an image in WordPress Media Library
- Check that it appears in Cloud Storage:

```bash
gcloud storage ls gs://YOUR-PROJECT-ID-media/
```

### Monitoring & Logs

**View Cloud Run Logs:**

```bash
gcloud run services logs read cms-wordpress \
  --region=us-central1 \
  --limit=50
```

**Real-time logs:**

```bash
gcloud run services logs tail cms-wordpress \
  --region=us-central1
```

**View Cloud SQL Logs:**

```bash
gcloud sql operations list --instance=wp-instance-*
```

---

## Configuration

### Custom Domain

**1. Verify domain ownership in GCP:**

```bash
gcloud domains verify yourdomain.com
```

**2. Map domain to Cloud Run:**

```bash
gcloud run domain-mappings create \
  --service=cms-wordpress \
  --domain=yourdomain.com \
  --region=us-central1
```

**3. Update DNS:**

Add the CNAME record shown in the output to your DNS provider.

**4. Update WordPress URL:**

```bash
cd terraform

terraform apply \
  -var="project_id=YOUR-PROJECT-ID" \
  -var="wordpress_url=https://yourdomain.com"
```

### Scaling Configuration

Edit `terraform/main.tf` to adjust scaling:

```hcl
locals {
  profile_config = {
    tiny = {
      db_tier       = "db-f1-micro"
      cpu_limit     = "1000m"
      memory_limit  = "512Mi"
      min_instances = 0        # Scale to zero
      max_instances = 10       # Increase max instances
    }
  }
}
```

Apply changes:

```bash
terraform apply -var="project_id=YOUR-PROJECT-ID"
```

### Enable CDN for Media

**1. Update terraform/main.tf:**

```hcl
module "media_storage" {
  # ...
  enable_cdn = true  # Change from false to true
}
```

**2. Apply changes:**

```bash
terraform apply -var="project_id=YOUR-PROJECT-ID"
```

**3. Update WP-Stateless to use CDN URL**

---

## Troubleshooting

### Common Issues

#### 1. "Billing not enabled" error

**Error:**
```
Error: Cloud SQL API has not been used in project before or it is disabled
```

**Solution:**
1. Go to [GCP Console Billing](https://console.cloud.google.com/billing)
2. Link project to billing account
3. Upgrade from free trial to paid account (no charge until you use resources)

#### 2. "Permission denied" errors

**Error:**
```
Error: Error creating service account: Permission denied
```

**Solution:**
```bash
# Check your permissions
gcloud projects get-iam-policy YOUR-PROJECT-ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR-EMAIL"

# Grant yourself Owner role (or specific roles from Prerequisites)
gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
  --member="user:YOUR-EMAIL" \
  --role="roles/owner"
```

#### 3. Docker push fails

**Error:**
```
unauthorized: You don't have the needed permissions
```

**Solution:**
```bash
# Re-configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Verify authentication
gcloud auth list
```

#### 4. Cloud SQL creation timeout

**Error:**
```
Error waiting for Creating CloudSQL instance: timeout while waiting for state
```

**Solution:**
- Cloud SQL can take 6-10 minutes to create
- Increase Terraform timeout (already set to 30 minutes in module)
- Check GCP Console for actual status: [Cloud SQL Instances](https://console.cloud.google.com/sql/instances)

#### 5. "State bucket not found"

**Error:**
```
Error: Failed to get existing workspaces: querying Cloud Storage failed
```

**Solution:**
```bash
# Verify bucket exists
gcloud storage ls gs://YOUR-PROJECT-ID-terraform-state/

# If not, recreate it
./scripts/bootstrap-state-bucket.sh YOUR-PROJECT-ID us-central1

# Verify main.tf has correct bucket name
cat terraform/main.tf | grep -A 3 "backend"
```

#### 6. WordPress shows "Error establishing database connection"

**Causes:**
- Cloud SQL Proxy sidecar not running
- Database credentials incorrect
- Private Service Connection not established

**Solution:**
```bash
# Check Cloud Run logs
gcloud run services logs read cms-wordpress --region=us-central1 --limit=100

# Check database instance
gcloud sql instances describe wp-instance-* --format="value(state)"

# Verify secrets exist
gcloud secrets versions access latest --secret="wordpress-db-password"

# Redeploy Cloud Run
cd terraform
terraform taint module.wordpress_cloudrun.google_cloud_run_v2_service.service
terraform apply -var="project_id=YOUR-PROJECT-ID"
```

### Getting Help

**Check logs:**
```bash
# Cloud Run
gcloud run services logs read cms-wordpress --region=us-central1

# Cloud SQL
gcloud sql operations list --instance=wp-instance-*

# Terraform
terraform show
```

**Validate Terraform:**
```bash
cd terraform
terraform validate
terraform fmt -check
```

**Run cost estimation:**
```bash
./scripts/estimate-costs.sh YOUR-PROJECT-ID
```

---

## Teardown

### Delete Everything

**Quick teardown:**

```bash
cd terraform
terraform destroy -var="project_id=YOUR-PROJECT-ID"
```

Type `yes` when prompted.

**This will delete:**
- Cloud Run service
- Cloud SQL instance (and all data)
- Cloud Storage media bucket (and all files)
- VPC network and Cloud NAT
- Service accounts
- Secrets
- Artifact Registry images

**NOT deleted (manual cleanup required):**
- Terraform state bucket (safety measure)
- GCP project

### Cleanup State Bucket

```bash
# Delete bucket (only after terraform destroy)
gcloud storage rm -r gs://YOUR-PROJECT-ID-terraform-state/
```

### Delete Project (Nuclear Option)

```bash
# This deletes EVERYTHING in the project
gcloud projects delete YOUR-PROJECT-ID
```

---

## Next Steps

### Production Readiness

- [ ] Set up custom domain with SSL
- [ ] Configure Cloud Armor for DDoS protection
- [ ] Enable Cloud SQL automatic backups
- [ ] Set up monitoring and alerting
- [ ] Configure WordPress caching plugin
- [ ] Review and harden IAM permissions
- [ ] Enable Cloud SQL high availability (if critical)
- [ ] Set up CI/CD for WordPress updates

### Cost Optimization

- [ ] Review actual usage with `estimate-costs.sh`
- [ ] Adjust min/max instances based on traffic
- [ ] Enable Cloud Storage lifecycle policies
- [ ] Consider committed use discounts for sustained workloads
- [ ] Set up billing alerts

### Further Customization

- [ ] Add more deployment profiles (small, medium, enterprise)
- [ ] Configure Cloud CDN for static assets
- [ ] Add Cloud Armor WAF rules
- [ ] Set up multi-region deployment
- [ ] Implement backup/restore automation
- [ ] Add WordPress plugin pre-installation

---

## Resources

- [GCP Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL for MySQL](https://cloud.google.com/sql/docs/mysql)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [WordPress Documentation](https://wordpress.org/support/)
- [WP-Stateless Plugin](https://wordpress.org/plugins/wp-stateless/)

---

**Questions?** [Open an issue](https://github.com/yourusername/serverless-wordpress-gcp/issues)
