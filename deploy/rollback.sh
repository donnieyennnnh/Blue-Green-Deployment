#!/usr/bin/env bash
# rollback.sh — flip Nginx back to the previously-live color.
#
# Pre-req: the "other" color's container must still be running (deploy.sh
# leaves it as a safety net). If the previous color was never started
# (i.e. this is the first deploy) rollback refuses — nothing to roll back to.

set -euo pipefail

NGINX_CONF="/etc/nginx/sites-available/bobross-gallery"
BLUE_PORT=3001
GREEN_PORT=3002
BLUE_NAME="bobross-gallery-blue"
GREEN_NAME="bobross-gallery-green"

if [[ ! -f "$NGINX_CONF" ]]; then
  echo "No Nginx config at $NGINX_CONF — nothing to roll back." >&2
  exit 1
fi

if   grep -q "127.0.0.1:$BLUE_PORT"  "$NGINX_CONF"; then
  CURRENT=blue;  PREV=green; PREV_PORT=$GREEN_PORT; PREV_NAME=$GREEN_NAME
elif grep -q "127.0.0.1:$GREEN_PORT" "$NGINX_CONF"; then
  CURRENT=green; PREV=blue;  PREV_PORT=$BLUE_PORT;  PREV_NAME=$BLUE_NAME
else
  echo "Could not detect current color from $NGINX_CONF" >&2
  exit 1
fi

echo "==> Current live color: $CURRENT"
echo "==> Rolling back to:    $PREV"

if ! docker ps --format '{{.Names}}' | grep -q "^$PREV_NAME$"; then
  echo "✗ Rollback target $PREV_NAME is not running — cannot roll back." >&2
  echo "  Only $CURRENT is up. You'll need to redeploy manually." >&2
  exit 1
fi

if ! curl -fsS "http://127.0.0.1:$PREV_PORT/health" > /dev/null; then
  echo "✗ $PREV_NAME is running but failed /health — refusing to roll back to it." >&2
  exit 1
fi

echo "==> Swapping Nginx upstream to $PREV"
sudo tee "$NGINX_CONF" > /dev/null <<EOF
# Managed by deploy/rollback.sh — do not edit by hand.
upstream bobross_app {
    server 127.0.0.1:$PREV_PORT;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://bobross_app;
        proxy_http_version 1.1;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo nginx -t
sudo systemctl reload nginx

sleep 1
if curl -fsS http://127.0.0.1/health | grep -q "\"color\":\"$PREV\""; then
  echo "==> Rollback complete. Live: $PREV"
else
  echo "✗ Nginx reload succeeded but /health still reports non-$PREV. Check manually." >&2
  exit 1
fi
