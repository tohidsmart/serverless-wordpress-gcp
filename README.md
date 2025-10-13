# WordPress on GCP Cloud Run

**Production-ready WordPress hosting for $21/month. Own your infrastructure, not rent it.**

Deploy a scalable, secure WordPress site on Google Cloud Platform in minutes. No vendor lock-in, full infrastructure control, and costs that scale with your traffic.

---

## Why This vs Managed WordPress?

| Feature | **This Solution** | WP Engine | Kinsta |
|---------|-------------------|-----------|--------|
| **Monthly Cost** | **$21** | $25-30 | $35 |
| **Traffic Included** | 100K requests | 25K visits | 25K visits |
| **Auto-scaling** | ✅ Unlimited | ❌ Fixed resources | ❌ Fixed resources |
| **Infrastructure Control** | ✅ Full access | ❌ Black box | ❌ Black box |
| **Infrastructure as Code** | ✅ Terraform | ❌ | ❌ |
| **Vendor Lock-in** | ✅ None - you own it | ❌ Locked | ❌ Locked |
| **Custom Architecture** | ✅ Fully customizable | ❌ Limited | ❌ Limited |
| **Database Backups** | ✅ Auto + PITR | ✅ | ✅ |
| **CDN for Media** | ✅ Google Cloud Storage | ✅ | ✅ |
| **One-Click Deploy** | ✅ | ✅ | ✅ |
| **Multi-region** | ✅ 40+ regions | ❌ Limited | ❌ Limited |

**The Bottom Line:** Save 40% on costs while getting unlimited scalability and full control over your infrastructure.

---

## Features

### Infrastructure
- **Auto-scaling Cloud Run** - Scales from 0 to 1000+ instances based on traffic
- **Private Cloud SQL (MySQL 8.0)** - Secure database with automatic backups and point-in-time recovery
- **Cloud Storage for Media** - Durable object storage with optional CDN
- **Private Networking** - VPC with Cloud NAT for secure, isolated environment
- **Secret Management** - Automated credential generation and secure storage

### Developer Experience
- **Infrastructure as Code** - 100% reproducible deployments via Terraform
- **One-Click Deployment** - Single command deploys entire infrastructure
- **Multi-container Architecture** - WordPress + Cloud SQL Proxy sidecar pattern
- **Modular Design** - Reusable Terraform modules for each component

### Security & Compliance
- **Private Database** - No public IP, accessed via Cloud SQL Proxy
- **Automated Secrets** - Random password generation for DB and WordPress admin
- **Resource-level IAM** - Principle of least privilege access
- **EU Data Residency** - GDPR-compliant secret replication (Premium)

---

## Cost Breakdown

### Tiny Profile (Current Deployment)
*Based on actual Google Cloud pricing as of October 2025*

| Service | Details | Monthly Cost |
|---------|---------|--------------|
| **Cloud Run** | 1 CPU, 512MB RAM (request-based) | $9.54 |
| **Cloud SQL MySQL** | db-f1-micro (0.6GB RAM) | $10.17 |
| **Cloud Storage** | 10GB media storage | $0.60 |
| **Artifact Registry** | 10GB container images | $0.95 |
| **Secret Manager** | 3 secrets | $0.00 |
| **Networking** | VPC, Cloud NAT | Included in Cloud Run |
| **TOTAL** | | **$21.25/month** |

**What you get for $21/month:**
- 100,000 requests/month (Cloud Run free tier)
- Automatic scaling from 0 to 3 instances
- Automated daily backups with 7-day retention
- 10GB media storage
- Private, secure database
- SSL/TLS certificates (via Cloud Run)

**Cost scales with usage:**
- Pay only for actual compute time (request-based billing)
- No charge when site has zero traffic
- Additional requests: $0.40 per million

---

## Quick Start

### Prerequisites
1. [Google Cloud Account](https://cloud.google.com/) with billing enabled
2. [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and configured
3. [Terraform](https://www.terraform.io/downloads) (v1.5+)
4. [Docker](https://docs.docker.com/get-docker/) (for custom WordPress image)

### Deploy in 3 Commands

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/serverless-wordpress-gcp.git
cd serverless-wordpress-gcp

# 2. Configure gcloud authentication
gcloud auth application-default login

# 3. Deploy everything
./scripts/end-to-end-deploy.sh YOUR_PROJECT_ID
```

**That's it!** The script will:
- ✅ Enable required GCP APIs
- ✅ Create Terraform state bucket
- ✅ Deploy infrastructure (VPC, Database, Cloud Run)
- ✅ Build and push custom WordPress image
- ✅ Output your WordPress URL

Deployment takes ~8-12 minutes.

---

## Architecture

```
Internet
   │
   ▼
Cloud Run (WordPress)
   │
   ├─► Cloud SQL Proxy (sidecar) ──► Cloud SQL (MySQL)
   │
   ├─► Cloud Storage (media files)
   │
   └─► Secret Manager (credentials)
```

**Key Components:**
- **Cloud Run**: Serverless container platform running WordPress
- **Cloud SQL Proxy**: Secure connection to private database
- **Cloud Storage**: Object storage for WordPress media uploads
- **VPC + Cloud NAT**: Private networking with controlled egress
- **Secret Manager**: Encrypted storage for database and admin passwords

---

## What's Included

### Free Version (Main Branch)
- ✅ Complete infrastructure deployment
- ✅ One-click deployment script
- ✅ Terraform modules with full documentation
- ✅ Docker configuration for custom WordPress
- ✅ Cost estimation scripts
- ✅ Basic deployment guide

### Premium Version (Coming Soon)
- 🔒 Multiple deployment profiles (small, medium, enterprise)
- 🔒 FinOps add-ons (budgets, spending alerts, forecasting)
- 🔒 Enhanced compliance (audit logs, GDPR tools)
- 🔒 Comprehensive documentation (architecture diagrams, video tutorials)
- 🔒 Production readiness checklist
- 🔒 Load testing and performance optimization guides

---

## Documentation

- **[Deployment Guide](DEPLOYMENT.md)** - Detailed deployment instructions
- **[Terraform Modules](terraform/modules/)** - Module documentation with IAM requirements
- **[Contributing](CONTRIBUTING.md)** - Contribution guidelines
- **[Cost Estimation](scripts/estimate-costs.sh)** - Calculate actual deployment costs

---

## Use Cases

**Perfect for:**
- 🚀 **Startups & SMBs** - Cost-effective hosting that scales with growth
- 💼 **Agencies** - Deploy client sites with full infrastructure control
- 🧑‍💻 **Developers** - Learn cloud-native architecture and IaC
- 🏢 **Enterprises** - GDPR-compliant, auditable infrastructure

**Not ideal for:**
- Sites requiring 24/7 sub-100ms response times (cold starts ~1-2s)
- WordPress multisite installations (not yet supported)
- Heavy WordPress plugin dependencies on local filesystem

---

## Comparison: Traditional vs This Solution

| Aspect | Traditional Hosting | **This Solution** |
|--------|---------------------|-------------------|
| **Setup Time** | Hours (manual) | 10 minutes (automated) |
| **Scaling** | Manual, downtime required | Automatic, zero downtime |
| **Infrastructure** | Fixed resources, over-provision | Pay for actual usage |
| **Reproducibility** | Manual docs, human error | Code-based, version controlled |
| **Multi-region** | Complex, expensive | Change 1 variable |
| **Disaster Recovery** | Manual backups, manual restore | Automated backups, declarative restore |
| **Cost** | Fixed monthly fee | Variable, scales with traffic |

---

## Frequently Asked Questions

**Q: How does this compare to AWS Lightsail or DigitalOcean App Platform?**
A: Those are also good options, but this solution gives you full infrastructure control with Terraform. You can customize networking, security, and scaling behavior. Plus, GCP's Cloud Run offers more generous free tier (100K requests/month vs 3.5GB-hours).

**Q: What about WordPress updates?**
A: You control the WordPress version in your Docker image. Rebuild and redeploy to update. Consider using official WordPress base images tagged with specific versions.

**Q: Can I use my own domain?**
A: Yes! Cloud Run provides a default `*.run.app` domain, but you can [map custom domains](https://cloud.google.com/run/docs/mapping-custom-domains) with automatic SSL certificates.

**Q: How do I access the WordPress admin?**
A: After deployment, visit `https://your-service-url.run.app/wp-admin`. Use the admin password from Secret Manager (run `terraform output wordpress_admin_password`).

**Q: What about backups?**
A: Cloud SQL automatically creates daily backups with 7-day retention. You can also enable point-in-time recovery for additional protection.

---

## Support & Community

- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/serverless-wordpress-gcp/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/yourusername/serverless-wordpress-gcp/discussions)
- 📚 **Wiki**: [Project Wiki](https://github.com/yourusername/serverless-wordpress-gcp/wiki)

---

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

---

## Credits

Built with:
- [Terraform](https://www.terraform.io/)
- [Google Cloud Platform](https://cloud.google.com/)
- [WordPress](https://wordpress.org/)
- [Cloud SQL Proxy](https://github.com/GoogleCloudPlatform/cloud-sql-proxy)

---

**Ready to own your infrastructure?** [Get started →](DEPLOYMENT.md)
