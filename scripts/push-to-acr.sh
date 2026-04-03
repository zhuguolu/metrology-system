#!/usr/bin/env sh
set -eu

REGISTRY="${REGISTRY:-crpi-52xa45ikkzp96ntt.cn-hangzhou.personal.cr.aliyuncs.com}"
NAMESPACE="${NAMESPACE:-zglweb}"
REPOSITORY="${REPOSITORY:-zspace-backup}"

BACKEND_IMAGE="${BACKEND_IMAGE:-$REGISTRY/$NAMESPACE/$REPOSITORY:backend-latest}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-$REGISTRY/$NAMESPACE/$REPOSITORY:frontend-latest}"

echo "Building local images..."
docker compose build backend frontend

echo "Tagging images..."
docker tag metrology-system-backend:latest "$BACKEND_IMAGE"
docker tag metrology-system-frontend:latest "$FRONTEND_IMAGE"

echo "Pushing backend image: $BACKEND_IMAGE"
docker push "$BACKEND_IMAGE"

echo "Pushing frontend image: $FRONTEND_IMAGE"
docker push "$FRONTEND_IMAGE"

echo "Done."
