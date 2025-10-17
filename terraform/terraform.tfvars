

# Project Configuration
project_id  = ""
region      = "us-central1"
zones       = ["us-central1-a"]
name_prefix = "cms"

# Labels
labels = {
  managed_by  = "terraform"
  purpose     = "cms-platform"
  environment = "production"
}

# Bootstrap Configuration
artifact_registry_name = "docker-images"


# Network Configuration
subnet_cidr = "10.0.0.0/16"

private_ip_prefix_length = 20
enable_cdn_for_media     = true

# WordPress Configuration

deployment_profile = "small"
