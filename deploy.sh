#!/bin/bash
read -p "Enter Domain: " DOMAIN
apt update && apt install -y docker-compose nginx certbot python3-certbot-nginx
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email
cat << EON > /etc/nginx/sites-available/zte-olt-manager
server { listen 80; server_name $DOMAIN; return 301 https://\$host\$request_uri; }
server { listen 443 ssl; server_name $DOMAIN; ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem; location / { proxy_pass http://localhost:5000; } }
EON
ln -s /etc/nginx/sites-available/zte-olt-manager /etc/nginx/sites-enabled/
systemctl restart nginx
docker-compose up -d --build
echo "Access: https://$DOMAIN"
