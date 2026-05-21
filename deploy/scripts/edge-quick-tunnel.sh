#!/usr/bin/env bash
# Edge tarafı için Cloudflare Quick Tunnel akışı:
#
# 1. cloudflared ve postgres'i başlat
# 2. cloudflared log'undan trycloudflare.com URL'sini yakala
# 3. URL'yi .env içine QUICKSERVE_PUBLIC_EDGE_URL olarak yaz
# 4. Edge servisini yeniden başlat (yeni env ile)
#
# Kullanım:
#   cd deploy/edge
#   ../scripts/edge-quick-tunnel.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDGE_DIR="$(cd "$SCRIPT_DIR/../edge" && pwd)"
cd "$EDGE_DIR"

if [[ ! -f .env ]]; then
  echo "HATA: $EDGE_DIR/.env yok. Önce: cp .env.example .env" >&2
  exit 1
fi

echo "==> postgres + cloudflared başlatılıyor"
docker compose up -d postgres cloudflared

echo "==> Quick Tunnel URL bekleniyor (en fazla 60 sn)"
TUNNEL_URL=""
for i in $(seq 1 60); do
  LOG=$(docker compose logs --no-color cloudflared 2>/dev/null || true)
  TUNNEL_URL=$(echo "$LOG" | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -n1 || true)
  if [[ -n "$TUNNEL_URL" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$TUNNEL_URL" ]]; then
  echo "HATA: trycloudflare URL bulunamadı. 'docker compose logs cloudflared' ile kontrol et." >&2
  exit 1
fi

echo "==> Tunnel hazır: $TUNNEL_URL"

# .env içine QUICKSERVE_PUBLIC_EDGE_URL=$TUNNEL_URL yaz (idempotent)
if grep -qE '^QUICKSERVE_PUBLIC_EDGE_URL=' .env; then
  # macOS/BSD sed uyumlu
  TMP=$(mktemp)
  awk -v url="$TUNNEL_URL" \
    'BEGIN{done=0} /^QUICKSERVE_PUBLIC_EDGE_URL=/{print "QUICKSERVE_PUBLIC_EDGE_URL="url; done=1; next}{print} END{if(!done) print "QUICKSERVE_PUBLIC_EDGE_URL="url}' \
    .env > "$TMP"
  mv "$TMP" .env
else
  echo "QUICKSERVE_PUBLIC_EDGE_URL=$TUNNEL_URL" >> .env
fi

echo "==> .env güncellendi"
echo "==> Edge ve Caddy başlatılıyor / yeniden oluşturuluyor"
docker compose up -d --force-recreate edge caddy

echo
echo "Bitti."
echo "  Edge public URL: $TUNNEL_URL"
echo "  Logu izlemek için: docker compose logs -f edge cloudflared"
