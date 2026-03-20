#!/bin/bash
set -e

read -p "Enter Domain: " DOMAIN

# Install dependencies
apt update && apt install -y docker.io docker-compose-plugin nginx certbot python3-certbot-nginx

# Step 1: Create HTTP-only nginx config first (so certbot can verify the domain)
cat << EON > /etc/nginx/sites-available/zte-olt-manager
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:5000;
    }
}
EON

# Enable the site (force overwrite if symlink exists)
ln -sf /etc/nginx/sites-available/zte-olt-manager /etc/nginx/sites-enabled/zte-olt-manager

# Reload nginx with HTTP-only config
systemctl daemon-reload
systemctl restart nginx

# Step 2: Obtain SSL certificate (certbot will also update the nginx config)
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email

# Reload nginx with the updated SSL config
systemctl reload nginx

# Step 3: Start the application
docker compose up -d --build

echo "Access: https://$DOMAIN"
