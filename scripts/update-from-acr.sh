#!/usr/bin/env sh
set -eu

if [ "${BACKEND_IMAGE:-}" = "" ] || [ "${FRONTEND_IMAGE:-}" = "" ]; then
  echo "Please set BACKEND_IMAGE and FRONTEND_IMAGE in .env first."
  exit 1
fi

echo "Pulling images..."
docker pull "$BACKEND_IMAGE"
docker pull "$FRONTEND_IMAGE"

echo "Restarting services..."
docker compose -f docker-compose.deploy.yml up -d

echo "Current status:"
docker compose -f docker-compose.deploy.yml ps
