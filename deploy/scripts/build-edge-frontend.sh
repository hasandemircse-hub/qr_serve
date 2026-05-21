#!/usr/bin/env bash
# edge_frontend (Flutter Web) → build/web
# EDGE_BASE_URL ve CLOUD_BASE_URL boş bırakılırsa istekler sayfa origin'ine gider:
#   * Personel LAN'da edge.local üzerinden açar -> Caddy hem web hem API'yi karşılar
#   * Cloudflare Tunnel hostname üzerinden de aynı şekilde çalışır.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT/edge_frontend"

flutter pub get
flutter build web \
  --release \
  --dart-define=EDGE_BASE_URL= \
  --dart-define=CLOUD_BASE_URL=

echo
echo "OK -> $REPO_ROOT/edge_frontend/build/web"
