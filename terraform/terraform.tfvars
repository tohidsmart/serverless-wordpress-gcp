

# Project Configuration
project_id  = ""
region      = "europe-west1"
zones       = ["europe-west1-b"]
name_prefix = "cms"

# Labels
labels = {
  managed_by  = "terraform"
  purpose     = "cms-platform"
  environment = "production"
}

# Bootstrap Configuration
artifact_registry_name = "docker-images"
enable_apis            = true


# Network Configuration
subnet_cidr = "10.0.0.0/16"

private_ip_prefix_length = 20
enable_cdn_for_media     = true

# WordPress Configuration

service_image_tag  = "0.0.25"
deployment_profile = "tiny"
