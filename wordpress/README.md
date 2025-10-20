# WordPress Configuration

Custom WordPress Docker image optimized for GCP Cloud Run.

---

## WordPress Version

**Current Version:** `6.7`

Defined in `Dockerfile` as build argument. Can be customized:

```bash
docker build --build-arg WORDPRESS_VERSION=6.6 -t wordpress-gcp ./wordpress
```

---

## Installing Themes

Add theme slugs to `themes.txt`, one per line:

```
# Format: theme-slug.version or theme-slug (for latest)
astra.4.11.13
twentytwentyfour
```

**Where to find theme slugs:**
- Visit [wordpress.org/themes](https://wordpress.org/themes/)
- The slug is in the URL: `wordpress.org/themes/THEME-SLUG/`

**Premium themes from third-party sources are not supported.**

---

## Installing Plugins

Add plugin slugs to `plugins.txt`, one per line:

```
# Essential plugins (pre-configured)
wp-stateless
astra-sites.4.4.40

# Add your plugins below
# Format: plugin-slug.version or plugin-slug (for latest)
woocommerce
contact-form-7
wp-super-cache
```

**Where to find plugin slugs:**
- Visit [wordpress.org/plugins](https://wordpress.org/plugins/)
- The slug is in the URL: `wordpress.org/plugins/PLUGIN-SLUG/`

**Premium plugins from third-party sources are not supported.**

---

## Deployment

After adding themes/plugins, deploy using the end-to-end script:

```bash
./scripts/end-to-end-deploy.sh YOUR_PROJECT_ID
```

The script automatically:
- Builds the Docker image with your themes/plugins
- Pushes to Artifact Registry
- Deploys to Cloud Run

---

## Updating WordPress

1. Update version in `Dockerfile`:
   ```dockerfile
   ARG WORDPRESS_VERSION=6.8
   ```

2. Redeploy:
   ```bash
   ./scripts/end-to-end-deploy.sh YOUR_PROJECT_ID
   ```

---

## Performance Optimizations

Pre-configured optimizations:
- **OPcache enabled** - 40-50% faster PHP execution
- **Memory optimized** - Tuned for Cloud Run (2GB RAM)
- **Apache MPM tuned** - 20 workers for optimal performance
- **wp-stateless plugin** - Media files stored in Cloud Storage

---

## Important Notes

- **Plugin installation via WordPress admin is not persistent** - Changes are lost on container restart
- **Always add themes/plugins to the txt files** for persistent installation
- **Test updates in development first** before deploying to production

---

**For full deployment instructions, see:** [Main README](../README.md)
