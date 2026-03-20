#!/bin/bash
set -e

read -p "Enter Domain: " DOMAIN

# Install only what's missing (certbot + docker) - DO NOT reinstall nginx
apt update && apt install -y certbot python3-certbot-nginx docker.io docker-compose-plugin

# Step 1: Write HTTP-only config so certbot can verify domain ownership
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

# Step 2: Obtain SSL cert only (certonly = does NOT modify nginx config)
certbot certonly --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email

# Step 3: Write the full HTTP + HTTPS nginx config using the obtained cert
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

# Step 4: Start the application
docker compose up -d --build

echo "Access: https://$DOMAIN"
