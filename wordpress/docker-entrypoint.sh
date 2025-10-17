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

// Enable direct filesystem access (required for plugin/theme installation in containers)
define('FS_METHOD', 'direct');

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

# Ensure .htaccess exists with proper permissions
echo "Ensuring .htaccess file exists..."
touch /var/www/html/.htaccess
chown www-data:www-data /var/www/html/.htaccess
chmod 644 /var/www/html/.htaccess

# Check if wp-config.php exists before flushing rewrites
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "ERROR: wp-config.php not found! Cannot flush rewrite rules."
else
    # Flush rewrite rules to ensure permalinks work correctly on new containers
    echo "Flushing rewrite rules..."
    if ! wp rewrite flush --allow-root --path=/var/www/html 2>&1; then
        echo "WARNING: wp rewrite flush failed, trying alternative method..."
        # Manually create .htaccess for WordPress permalinks
        cat > /var/www/html/.htaccess <<'HTACCESS'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS
        chown www-data:www-data /var/www/html/.htaccess
        echo "Created .htaccess manually"
    fi
fi

# Debug: Check permalink structure
echo "Checking permalink structure:"
wp rewrite structure --allow-root --path=/var/www/html || echo "No permalink structure set"

# Debug: Check file permissions
echo "File permissions for .htaccess:"
ls -la /var/www/html/.htaccess || echo ".htaccess not found"

# Verify .htaccess was created
echo "Checking .htaccess content:"
cat /var/www/html/.htaccess || echo "ERROR: .htaccess file is EMPTY!"

# If still empty after flush, write it manually
if [ ! -s /var/www/html/.htaccess ]; then
    echo "WARNING: .htaccess is empty after flush, writing manually..."
    cat > /var/www/html/.htaccess <<'HTACCESS'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS
    chown www-data:www-data /var/www/html/.htaccess
    chmod 644 /var/www/html/.htaccess
    echo "Created .htaccess manually with default WordPress rules"
    echo "Final .htaccess content:"
    cat /var/www/html/.htaccess
fi

# Execute the main container command
exec "$@"
