#!/bin/bash
set -e

read -p "Enter Domain: " DOMAIN

# Install only what's missing (certbot + docker) - DO NOT reinstall nginx
apt update && apt install -y certbot python3-certbot-nginx docker.io docker-compose-plugin

# Step 1: Determine port (smart: re-use if free or ours, find new if taken by another app)
find_free_port() {
    local PORT=5501
    while ss -tlnp | grep -q ":$PORT "; do
        PORT=$((PORT + 1))
    done
    echo $PORT
}

port_owned_by_us() {
    local PORT=$1
    # Check if ANY zte-olt-manager container is currently bound to this port
    docker ps --format "{{.Names}} {{.Ports}}" 2>/dev/null \
        | grep "zte-olt-manager" \
        | grep -q ":${PORT}->"
}

if [ -f .env ] && grep -q "APP_PORT=" .env; then
    APP_PORT=$(grep "APP_PORT=" .env | cut -d'=' -f2)
    if ! ss -tlnp | grep -q ":$APP_PORT "; then
        echo "Re-using port $APP_PORT (currently free)"
    elif port_owned_by_us "$APP_PORT"; then
        echo "Re-using port $APP_PORT (owned by this app — will be replaced on restart)"
    else
        echo "Port $APP_PORT is taken by another app — finding a new port..."
        APP_PORT=$(find_free_port)
        echo "Assigned new port: $APP_PORT"
    fi
else
    APP_PORT=$(find_free_port)
    echo "First deploy — assigned port: $APP_PORT"
fi

# Save/update .env
echo "APP_PORT=$APP_PORT" > .env

# Step 2: Remove any broken/leftover config for this domain to start clean
rm -f /etc/nginx/sites-enabled/zte-olt-manager
rm -f /etc/nginx/sites-available/zte-olt-manager

# Step 3: Write HTTP-only config so certbot can verify domain ownership
cat << EON > /etc/nginx/sites-available/zte-olt-manager
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:$APP_PORT;
    }
}
EON

ln -sf /etc/nginx/sites-available/zte-olt-manager /etc/nginx/sites-enabled/zte-olt-manager
nginx -t && systemctl reload nginx

# Step 4: Obtain SSL certificate (certonly = does NOT auto-modify nginx config)
certbot certonly --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email

# Step 5: Write the full HTTP + HTTPS nginx config using the obtained cert
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
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EON

nginx -t && systemctl reload nginx

# Step 6: Start the application
docker compose up -d --build

echo "Access: https://$DOMAIN (proxied from port $APP_PORT)"
