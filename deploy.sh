#!/bin/bash
set -e

read -p "Enter Domain: " DOMAIN

# Install only what's missing (certbot + docker) - DO NOT reinstall nginx
apt update && apt install -y certbot python3-certbot-nginx docker.io docker-compose-plugin

# Step 1: Remove any broken/leftover config for this domain to start clean
rm -f /etc/nginx/sites-enabled/zte-olt-manager
rm -f /etc/nginx/sites-available/zte-olt-manager

# Step 2: Write HTTP-only config so certbot can verify domain ownership
cat << EON > /etc/nginx/sites-available/zte-olt-manager
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:5000;
    }
}
EON

ln -sf /etc/nginx/sites-available/zte-olt-manager /etc/nginx/sites-enabled/zte-olt-manager
nginx -t && systemctl reload nginx

# Step 3: Obtain SSL certificate (certonly = does NOT auto-modify nginx config)
certbot certonly --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email

# Step 4: Write the full HTTP + HTTPS nginx config using the obtained cert
cat << EON > /etc/nginx/sites-available/zte-olt-manager
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EON

nginx -t && systemctl reload nginx

# Step 5: Start the application
docker compose up -d --build

echo "Access: https://$DOMAIN"
