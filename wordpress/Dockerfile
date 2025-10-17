# Build arguments
ARG WORDPRESS_VERSION=6.7

# Stage 1: Download and prepare WordPress with plugins
FROM wordpress:${WORDPRESS_VERSION} AS builder

# Install required tools
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Configure PHP memory limit for WP-CLI
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/wp-cli-memory.ini

# Copy plugin and theme lists
COPY plugins.txt /tmp/plugins.txt
COPY themes.txt /tmp/themes.txt

# Download WordPress core
RUN wp core download --allow-root --path=/var/www/html --force

# Install GDPR compliance plugins from plugins.txt (without database connection)
RUN while IFS= read -r plugin || [ -n "$plugin" ]; do \
        [ -z "$plugin" ] && continue; \
        case "$plugin" in \#*) continue ;; esac; \
        echo ">>> Downloading plugin: $plugin"; \
        if curl -sS -f "https://downloads.wordpress.org/plugin/${plugin}.zip" -o /tmp/${plugin}.zip; then \
            unzip -q /tmp/${plugin}.zip -d /var/www/html/wp-content/plugins/ && \
            rm /tmp/${plugin}.zip && \
            echo "    ✓ Installed $plugin"; \
        else \
            echo "    ✗ Failed to download $plugin (not found on wordpress.org)"; \
            rm -f /tmp/${plugin}.zip; \
        fi; \
    done < /tmp/plugins.txt

# Install themes from themes.txt (if any)
RUN while IFS= read -r theme || [ -n "$theme" ]; do \
        [ -z "$theme" ] && continue; \
        case "$theme" in \#*) continue ;; esac; \
        echo ">>> Downloading theme: $theme"; \
        if curl -sS -f "https://downloads.wordpress.org/theme/${theme}.zip" -o /tmp/${theme}.zip; then \
            unzip -q /tmp/${theme}.zip -d /var/www/html/wp-content/themes/ && \
            rm /tmp/${theme}.zip && \
            echo "    ✓ Installed $theme"; \
        else \
            echo "    ✗ Failed to download $theme (not found on wordpress.org)"; \
            rm -f /tmp/${theme}.zip; \
        fi; \
    done < /tmp/themes.txt

# Stage 2: Final production image
ARG WORDPRESS_VERSION=6.7
FROM wordpress:${WORDPRESS_VERSION}

# Build arguments
ARG TZ=Europe/Berlin

# Install jq for JSON validation
RUN apt-get update && apt-get install -y jq && rm -rf /var/lib/apt/lists/*

# Copy optimized PHP configurations
# Performance: OPcache for 40-50% faster PHP execution
# Memory: Optimized settings for Cloud Run (1GB RAM)
COPY php-opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY php-performance.ini /usr/local/etc/php/conf.d/performance.ini

# Ensure proper permissions for WordPress directories
RUN chown -R www-data:www-data /var/www/html && \
    find /var/www/html -type d -exec chmod 755 {} \; && \
    find /var/www/html -type f -exec chmod 644 {} \;

# Copy WP-CLI from builder stage
COPY --from=builder /usr/local/bin/wp /usr/local/bin/wp

# Copy WordPress core with plugins and themes from builder
COPY --from=builder /var/www/html/ /var/www/html/

# Copy entrypoint script (wp-config.php will be generated at runtime)
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Enable mod_rewrite and configure Apache to allow .htaccess
RUN a2enmod rewrite

# Copy Apache configuration with AllowOverride All
COPY apache-wordpress.conf /etc/apache2/sites-available/000-default.conf

# Copy optimized Apache MPM configuration for Cloud Run
# Tuned for 1GB RAM: 20 workers @ ~45MB each = optimal memory usage
COPY apache-mpm.conf /etc/apache2/conf-available/mpm-tuning.conf
RUN a2enconf mpm-tuning

# Force HTTPS
ENV WORDPRESS_CONFIG_EXTRA="define('FORCE_SSL_ADMIN', true);"

# Set timezone (configurable via build arg)
ENV TZ=${TZ}

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]