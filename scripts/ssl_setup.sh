#!/bin/bash

# SSL Setup Script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$SCRIPT_DIR/.."

echo "🔐 Setting up HTTPS..."

if [ -z "$1" ]; then
    echo "Generating self-signed certificate..."
    openssl req -x509 -newkey rsa:4096 -nodes \
        -out $AI_DIR/ssl/cert.pem \
        -keyout $AI_DIR/ssl/key.pem \
        -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    echo "✅ Self-signed certificate generated"
else
    DOMAIN=$1
    sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    sudo ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem $AI_DIR/ssl/cert.pem
    sudo ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem $AI_DIR/ssl/key.pem
    echo "✅ SSL certificate configured for $DOMAIN"
fi
