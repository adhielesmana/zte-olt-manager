#!/bin/bash
set -e

read -p "Enter Domain: " DOMAIN

# Install only what's missing (certbot + docker) - DO NOT touch nginx
apt update && apt install -y certbot python3-certbot-nginx docker.io docker-compose-plugin

# Step 1: Write HTTP-only config for this domain (no SSL yet)
cat << EON > /etc/nginx/sites-available/zte-olt-manager
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:5000;
    }
}
EON

# Enable this site only (force overwrite if symlink already exists)
ln -sf /etc/nginx/sites-available/zte-olt-manager /etc/nginx/sites-enabled/zte-olt-manager

# Validate config and reload (NOT restart - keeps other domains alive)
nginx -t && systemctl reload nginx

# Step 2: Obtain SSL cert - certbot will modify only this domain's config
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email

# Reload nginx to apply SSL config
nginx -t && systemctl reload nginx

# Step 3: Start the application
docker compose up -d --build

echo "Access: https://$DOMAIN"
