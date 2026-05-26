#!/usr/bin/env bash
# QuickServe — "Self-contained Edge bundle" üreticisi.
#
# Çıktı: TEK bir tar.gz dosyası. İçinde:
#   * images/edge.tar             - Spring Boot Edge backend Docker imajı
#   * images/edge-caddy.tar       - Caddy + Flutter Web (frontend gömülü) imajı
#   * deploy/docker-compose.yml   - Compose dosyası
#   * deploy/Caddyfile            - Caddy konfig (referans, imaja zaten gömülü)
#   * deploy/.env.example         - .env şablonu
#   * install.sh                  - Edge cihazında 1 komutla kurulum
#   * VERSION                     - bundle tag'i
#
# Akış (sen — build sunucusu):
#   ./deploy/scripts/build-edge-images.sh --tag v0.1.0 --platform linux/amd64
#   → /tmp/quickserve-edge-bundle-v0.1.0.tar.gz   (≈190 MB)
#   → /tmp/quickserve-edge-bundle-v0.1.0.tar.gz.sha256
#
# Akış (Edge cihazı — git/git pull GEREKMEZ):
#   1. tar.gz'i bir klasöre kopyala (örn. /opt/quickserve-bundle/)
#   2. tar -xzf quickserve-edge-bundle-v0.1.0.tar.gz
#   3. bash install.sh        # docker load + .env hazırla + servisleri kaldır
#
# Notlar:
#   * Default platform linux/amd64 (Intel NUC, çoğu mini PC, Linux VM).
#     Pi/ARM hedef için: --platform linux/arm64
#   * Multi-platform aynı anda yapılabilir ama çıktı registry'ye gider, tar değil.
#     O modu istersek ayrı script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---- Argümanlar ----
TAG="local"
PLATFORM="linux/amd64"
OUTPUT_DIR="/tmp"
SKIP_BUILD="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)       TAG="$2"; shift 2 ;;
    --platform)  PLATFORM="$2"; shift 2 ;;
    --out)       OUTPUT_DIR="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD="1"; shift 1 ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) echo "Bilinmeyen argüman: $1"; exit 2 ;;
  esac
done

EDGE_IMG="quickserve/edge:${TAG}"
CADDY_IMG="quickserve/edge-caddy:${TAG}"
BUNDLE_NAME="quickserve-edge-bundle-${TAG}"
STAGING="${OUTPUT_DIR}/${BUNDLE_NAME}"
OUTPUT_GZ="${OUTPUT_DIR}/${BUNDLE_NAME}.tar.gz"

cd "$REPO_ROOT"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " QuickServe — Edge bundle paketleniyor (self-contained)"
echo "───────────────────────────────────────────────────────────────"
echo " Repo            : $REPO_ROOT"
echo " Platform        : $PLATFORM"
echo " Tag             : $TAG"
echo " Edge backend    : $EDGE_IMG"
echo " Edge caddy      : $CADDY_IMG"
echo " Çıktı bundle    : $OUTPUT_GZ"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ---- Ön koşullar ----
command -v docker >/dev/null || { echo "❌ docker bulunamadı"; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo "❌ docker buildx bulunamadı"; exit 1; }

if [[ "$SKIP_BUILD" == "0" ]]; then
  echo "==> Edge backend imajı build ediliyor ($PLATFORM)"
  docker buildx build \
    --platform "$PLATFORM" \
    --file deploy/edge/Dockerfile \
    --tag "$EDGE_IMG" \
    --load \
    .

  echo ""
  echo "==> Edge Caddy imajı build ediliyor ($PLATFORM, Flutter Web derleniyor)"
  docker buildx build \
    --platform "$PLATFORM" \
    --file deploy/edge/Dockerfile.caddy \
    --tag "$CADDY_IMG" \
    --load \
    .
else
  echo "==> --skip-build verildi; mevcut local imajlar kullanılacak"
fi

# ---- Doğrulama ----
echo ""
echo "==> Imajlar doğrulanıyor"
for img in "$EDGE_IMG" "$CADDY_IMG"; do
  if ! docker image inspect "$img" >/dev/null 2>&1; then
    echo "❌ Image bulunamadı: $img"
    exit 1
  fi
  arch=$(docker image inspect "$img" --format '{{.Architecture}}')
  size=$(docker image inspect "$img" --format '{{.Size}}')
  size_mb=$(( size / 1024 / 1024 ))
  echo "  ✓ $img   arch=$arch   size=${size_mb} MB"
done

# ---- Bundle staging klasörü hazırla ----
echo ""
echo "==> Bundle içeriği hazırlanıyor"
rm -rf "$STAGING" "$OUTPUT_GZ" "${OUTPUT_GZ}.sha256"
mkdir -p "$STAGING/images" "$STAGING/deploy"

# Docker imajlarını tar olarak save et
echo "  · Docker imajları save ediliyor"
docker save -o "$STAGING/images/edge.tar" "$EDGE_IMG"
docker save -o "$STAGING/images/edge-caddy.tar" "$CADDY_IMG"

# Compose + Caddyfile + .env.example
echo "  · Compose ve config dosyaları kopyalanıyor"
cp deploy/edge/docker-compose.yml "$STAGING/deploy/docker-compose.yml"
cp deploy/edge/Caddyfile           "$STAGING/deploy/Caddyfile"
cp deploy/edge/.env.example        "$STAGING/deploy/.env.example"

# Version dosyası
cat > "$STAGING/VERSION" <<EOF
bundle: quickserve-edge
tag: ${TAG}
platform: ${PLATFORM}
built_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
edge_image: ${EDGE_IMG}
caddy_image: ${CADDY_IMG}
EOF

# install.sh — Edge cihazında tek komutla kurulum
cat > "$STAGING/install.sh" <<'INSTALL_EOF'
#!/usr/bin/env bash
# QuickServe Edge — Bundle install.sh
# Bu scripti TAR'ı açtığın klasörde çalıştır.
#
# Yapacakları:
#   1. Docker imajlarını yükle (docker load).
#   2. /opt/quickserve/deploy/edge klasörünü oluştur, compose + Caddyfile + .env.example kopyala.
#   3. .env yoksa .env.example'dan oluştur; yardım göster.
#   4. .env varsa EDGE_TAG'i bu bundle tag'ine güncelle.
#   5. Servisleri başlat (sadece kullanıcı `--start` verirse).

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="/opt/quickserve/deploy/edge"
START="0"

for a in "$@"; do
  case "$a" in
    --start) START="1" ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  esac
done

# Bundle'ın tag'ini oku
TAG="$(grep '^tag:' "$HERE/VERSION" | awk '{print $2}')"
[[ -n "$TAG" ]] || { echo "❌ VERSION dosyasında tag bulunamadı"; exit 1; }

echo "──────────────────────────────────────────────────────"
echo " QuickServe Edge bundle install"
echo " Tag    : $TAG"
echo " Target : $TARGET"
echo "──────────────────────────────────────────────────────"

command -v docker >/dev/null || { echo "❌ docker yok. Önce kur."; exit 1; }

# 1) Docker imajlarını yükle
echo "==> Docker imajları yükleniyor (1-2 dk)"
docker load -i "$HERE/images/edge.tar"
docker load -i "$HERE/images/edge-caddy.tar"

# 2) Compose dosyalarını kopyala
echo "==> Compose ve config dosyaları $TARGET içine kopyalanıyor"
sudo mkdir -p "$TARGET"
sudo cp "$HERE/deploy/docker-compose.yml" "$TARGET/docker-compose.yml"
sudo cp "$HERE/deploy/Caddyfile"          "$TARGET/Caddyfile"
sudo cp "$HERE/deploy/.env.example"       "$TARGET/.env.example"

# 3) .env yönetimi
if [[ ! -f "$TARGET/.env" ]]; then
  sudo cp "$TARGET/.env.example" "$TARGET/.env"
  echo ""
  echo "⚠ $TARGET/.env yeni oluşturuldu (.env.example'dan)."
  echo "   Lütfen değerleri doldur (UUID'ler, secret'lar, cloudflared token, vs.)"
  echo "   sonra tekrar şu komutu çalıştır:"
  echo "       sudo bash $HERE/install.sh --start"
  exit 0
fi

# .env varsa: EDGE_TAG'i bundle tag'ine senkronla
if sudo grep -q '^EDGE_TAG=' "$TARGET/.env"; then
  sudo sed -i "s|^EDGE_TAG=.*|EDGE_TAG=$TAG|" "$TARGET/.env"
else
  echo "EDGE_TAG=$TAG" | sudo tee -a "$TARGET/.env" >/dev/null
fi
echo "  · EDGE_TAG=$TAG → $TARGET/.env içinde set edildi"

# 4) Servisleri başlat (opt-in)
if [[ "$START" == "1" ]]; then
  echo ""
  echo "==> Servisler başlatılıyor"
  cd "$TARGET"
  docker compose up -d
  docker compose ps
  echo ""
  echo "Log akışı için:  cd $TARGET && docker compose logs -f edge caddy cloudflared"
else
  echo ""
  echo "✅ Imajlar yüklü, compose dosyaları yerinde, .env hazır."
  echo "   Servisleri başlatmak için:"
  echo "       cd $TARGET && docker compose up -d"
fi
INSTALL_EOF
chmod +x "$STAGING/install.sh"

# Bundle'ı sıkıştır
echo ""
echo "==> Tar.gz oluşturuluyor (gzip -9, 1-2 dk)"
( cd "$OUTPUT_DIR" && tar -czf "$OUTPUT_GZ" "$BUNDLE_NAME" )
echo "  ✓ $OUTPUT_GZ hazır ($(du -h "$OUTPUT_GZ" | cut -f1))"

# Staging klasörünü temizle (kullanıcı .tar.gz'i kullanacak)
rm -rf "$STAGING"

# ---- Checksum (Edge'de doğrulama için) ----
echo ""
echo "==> SHA256 hesaplanıyor"
if command -v sha256sum >/dev/null; then
  ( cd "$OUTPUT_DIR" && sha256sum "$(basename "$OUTPUT_GZ")" | tee "${OUTPUT_GZ}.sha256" )
elif command -v shasum >/dev/null; then
  ( cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$OUTPUT_GZ")" | tee "${OUTPUT_GZ}.sha256" )
fi

cat <<EOF

═══════════════════════════════════════════════════════════════
✅ Self-contained bundle hazır.

İçindekiler:
  ├─ images/edge.tar              (Edge backend imajı)
  ├─ images/edge-caddy.tar        (Caddy + frontend imajı)
  ├─ deploy/docker-compose.yml    (yeni compose)
  ├─ deploy/Caddyfile             (referans)
  ├─ deploy/.env.example          (şablon)
  ├─ install.sh                   (Edge cihazında tek komutla kurulum)
  └─ VERSION

Sıradaki adım — Edge cihazına gönder:
  scp $OUTPUT_GZ ${OUTPUT_GZ}.sha256 <user>@<edge-host>:/tmp/

Edge cihazında çalıştır:
  cd /tmp
  sha256sum -c $(basename "$OUTPUT_GZ").sha256                  # doğrulama
  tar -xzf $(basename "$OUTPUT_GZ")
  cd quickserve-edge-bundle-${TAG}
  bash install.sh                                               # ilk kurulum (.env'i hazırlar)
  # → .env'i editle (UUID, token, secret'lar)
  sudo bash install.sh --start                                  # servisleri kaldır
═══════════════════════════════════════════════════════════════
EOF
