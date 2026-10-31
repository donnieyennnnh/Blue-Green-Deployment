#!/usr/bin/env bash
# deploy.sh — Blue-green deploy, runs on the EC2 via `ssh ... bash < deploy.sh`.
#
# Expected env vars (set by the SSH command line in ci.yml):
#   IMAGE  — full image ref, e.g. ghcr.io/<user>/bobross-gallery:sha-abc123
#
# What this does:
#   1. Figure out which color is currently live by reading the Nginx upstream
#   2. Pull the new image
#   3. Start the OPPOSITE color on its port, running the new image
#   4. Health-check that new container directly (not through Nginx)
#   5. Swap the Nginx upstream to the new color + reload
#   6. Leave the previously-live color running as a rollback safety net
#
# Idempotent: safe to re-run. Zero downtime: Nginx reload is sub-second and
# the previous container keeps serving while the new one starts up.

set -euo pipefail

IMAGE="${IMAGE:?IMAGE env var required}"

NGINX_CONF="/etc/nginx/sites-available/bobross-gallery"
BLUE_PORT=3001
GREEN_PORT=3002
BLUE_NAME="bobross-gallery-blue"
GREEN_NAME="bobross-gallery-green"

# ---------- 1. Determine current live color ----------
if [[ -f "$NGINX_CONF" ]] && grep -q "127.0.0.1:$BLUE_PORT" "$NGINX_CONF"; then
  CURRENT=blue;  NEW=green; NEW_PORT=$GREEN_PORT; NEW_NAME=$GREEN_NAME
elif [[ -f "$NGINX_CONF" ]] && grep -q "127.0.0.1:$GREEN_PORT" "$NGINX_CONF"; then
  CURRENT=green; NEW=blue;  NEW_PORT=$BLUE_PORT;  NEW_NAME=$BLUE_NAME
else
  # First blue-green deploy — nothing is live yet (or we're coming from Phase 5)
  CURRENT=none;  NEW=blue;  NEW_PORT=$BLUE_PORT;  NEW_NAME=$BLUE_NAME
fi

echo "==> Current live color: $CURRENT"
echo "==> Deploying new version to inactive color: $NEW (port $NEW_PORT)"

# ---------- 2. Pull new image ----------
echo "==> Pulling $IMAGE"
docker pull "$IMAGE"

# ---------- 3. Start new container on inactive port ----------
echo "==> Stopping any stale $NEW container"
docker stop "$NEW_NAME" 2>/dev/null || true
docker rm   "$NEW_NAME" 2>/dev/null || true

echo "==> Starting $NEW container on port $NEW_PORT"
docker run -d \
  --name    "$NEW_NAME" \
  --restart unless-stopped \
  -p 127.0.0.1:$NEW_PORT:3000 \
  -e APP_COLOR="$NEW" \
  "$IMAGE"

# ---------- 4. Health-check the new container directly ----------
echo "==> Waiting for $NEW to pass /health"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "http://127.0.0.1:$NEW_PORT/health" > /dev/null; then
    echo "   ✓ $NEW healthy (attempt $i)"
    break
  fi
  if [[ $i -eq 10 ]]; then
    echo "   ✗ $NEW never came up — showing logs and aborting"
    docker logs --tail=80 "$NEW_NAME" || true
    docker stop "$NEW_NAME" || true
    exit 1
  fi
  sleep 2
done

# ---------- 5. Swap Nginx upstream ----------
echo "==> Updating Nginx upstream: $CURRENT → $NEW (port $NEW_PORT)"
sudo tee "$NGINX_CONF" > /dev/null <<EOF
# Managed by deploy/deploy.sh — do not edit by hand.
# The upstream port determines which color is live (3001 = blue, 3002 = green).
upstream bobross_app {
    server 127.0.0.1:$NEW_PORT;
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

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/bobross-gallery
sudo rm   -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

# ---------- 6. Verify end-to-end + clean up legacy Phase 5 container ----------
sleep 1
if curl -fsS http://127.0.0.1/health | grep -q "\"color\":\"$NEW\""; then
  echo "   ✓ End-to-end: Nginx is now serving $NEW"
else
  echo "   ✗ Nginx not serving $NEW yet — check /etc/nginx/sites-enabled/"
  exit 1
fi

# Remove the Phase 5 single-container holdover, if any.
if docker ps --format '{{.Names}}' | grep -q "^bobross-gallery$"; then
  echo "==> Removing legacy Phase 5 container 'bobross-gallery'"
  docker stop bobross-gallery || true
  docker rm   bobross-gallery || true
fi

echo "==> Deploy complete."
echo "    Live: $NEW   |   Rollback target: $CURRENT (still running on its port)"
