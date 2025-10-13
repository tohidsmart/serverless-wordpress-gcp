#!/bin/bash
set -e

# Write and validate service account key for WP-Stateless
KEY_FILE="/tmp/service-account-key.json"
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS_JSON}" ]; then
    echo "Writing service account key to ${KEY_FILE}..."
    echo "${GOOGLE_APPLICATION_CREDENTIALS_JSON}" > "${KEY_FILE}"
    chmod 600 "${KEY_FILE}"

    # Validate JSON format
    if command -v jq >/dev/null 2>&1; then
        if jq empty "${KEY_FILE}" 2>/dev/null; then
            echo "✓ Service account key is valid JSON"
        else
            echo "ERROR: Service account key is not valid JSON!"
            cat "${KEY_FILE}"
            exit 1
        fi
    else
        echo "Warning: jq not available, skipping JSON validation"
    fi
fi

# Always regenerate wp-config.php to ensure correct settings
echo "Generating wp-config.php..."
wp config create \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${WORDPRESS_DB_PASSWORD}" \
    --dbhost="127.0.0.1:3306" \
    --allow-root \
    --path=/var/www/html \
    --force \
    --extra-php <<PHP
// Force HTTPS in production (Cloud Run), allow HTTP in local development
if ('${ENVIRONMENT:-production}' === 'production') {
    define('FORCE_SSL_ADMIN', true);
    \$_SERVER['HTTPS'] = 'on';
}

// Set WordPress site URLs from required environment variable
define('WP_HOME', '${WORDPRESS_URL}');
define('WP_SITEURL', '${WORDPRESS_URL}');

define('GDPR_COOKIE_CONSENT_ENABLE', true);

// WP-Stateless Configuration - Use service account key JSON directly
define('WP_STATELESS_MEDIA_BUCKET', '${STATELESS_MEDIA_BUCKET}');
define('WP_STATELESS_MEDIA_MODE', 'stateless');
define('WP_STATELESS_MEDIA_JSON_KEY', '${GOOGLE_APPLICATION_CREDENTIALS_JSON}');
PHP

# Check if WordPress is already installed
if ! wp core is-installed --allow-root --path=/var/www/html 2>/dev/null; then
    echo "Installing WordPress..."

    # Get the site URL from required environment variable
    SITE_URL="${WORDPRESS_URL:?Error: WORDPRESS_URL environment variable must be set}"

    # Install WordPress
    wp core install \
        --url="${SITE_URL}" \
        --title="${WORDPRESS_TITLE:-My WordPress Site}" \
        --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD:?Error: Wordpress admin password must be set}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
        --skip-email \
        --allow-root \
        --path=/var/www/html

    echo "WordPress installed successfully!"

    # Set permalink structure for better SEO
    wp rewrite structure '/%postname%/' --allow-root --path=/var/www/html

    echo "WordPress setup complete!"
else
    echo "WordPress already installed."
fi


# Activate all plugins
echo "Activating all plugins..."
wp plugin activate --all --allow-root --path=/var/www/html || true


# Execute the main container command
exec "$@"
