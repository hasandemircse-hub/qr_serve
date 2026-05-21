#!/usr/bin/env bash
# cloud_frontend (Flutter Web) → build/web
# Üretim Caddy aynı host'tan hem statik web'i hem Cloud API'yi servis ettiği için
# CLOUD_BASE_URL boş bırakılır; istekler sayfa origin'ine gider.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT/cloud_frontend"

flutter pub get
flutter build web \
  --release \
  --dart-define=CLOUD_BASE_URL=

echo
echo "OK -> $REPO_ROOT/cloud_frontend/build/web"
