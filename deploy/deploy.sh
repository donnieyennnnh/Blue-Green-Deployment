#!/usr/bin/env bash
# deploy.sh — runs on the EC2 via `ssh ... bash < deploy/deploy.sh`.
#
# Expected env vars (set by the SSH command line, see .github/workflows/ci.yml):
#   IMAGE      — full image ref, e.g. ghcr.io/<user>/bobross-gallery:sha-abc123
#   APP_COLOR  — "blue" or "green" (Phase 5 uses "blue"; Phase 6 toggles)
#
# What this does:
#   1. docker pull the image
#   2. stop + remove the old container (if present)
#   3. start the new container on localhost:3000
#   4. write an Nginx reverse-proxy config  (80 → 127.0.0.1:3000)
#   5. reload Nginx
#   6. health-check through Nginx (http://localhost/health)

set -euo pipefail

IMAGE="${IMAGE:?IMAGE env var required}"
APP_COLOR="${APP_COLOR:-blue}"
CONTAINER_NAME="bobross-gallery"

echo "==> Pulling $IMAGE"
docker pull "$IMAGE"

echo "==> Stopping + removing old container (if any)"
docker stop  "$CONTAINER_NAME" 2>/dev/null || true
docker rm    "$CONTAINER_NAME" 2>/dev/null || true

echo "==> Starting new container (color=$APP_COLOR)"
docker run -d \
  --name       "$CONTAINER_NAME" \
  --restart    unless-stopped \
  -p 127.0.0.1:3000:3000 \
  -e APP_COLOR="$APP_COLOR" \
  "$IMAGE"

echo "==> Writing Nginx reverse-proxy config"
sudo tee /etc/nginx/sites-available/bobross-gallery > /dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    # Phase 5: single container on port 3000.
    # Phase 6 will replace this with an upstream block that swaps between
    # blue (3001) and green (3002) for blue-green deployment.
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/bobross-gallery /etc/nginx/sites-enabled/bobross-gallery
sudo rm   -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

echo "==> Health check via Nginx"
sleep 2
for i in 1 2 3 4 5; do
  if curl -fsS http://127.0.0.1/health > /dev/null; then
    echo "==> Deploy OK (health passed on attempt $i)"
    exit 0
  fi
  echo "   health not ready yet, retrying ($i/5)..."
  sleep 2
done

echo "==> Health check FAILED after 5 attempts"
docker logs --tail=50 "$CONTAINER_NAME" || true
exit 1
