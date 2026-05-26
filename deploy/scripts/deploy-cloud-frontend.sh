#!/usr/bin/env bash
# deploy-cloud-frontend.sh
# ---------------------------------------------------------------------------
# Yerel makinendeki kodları cloud_frontend (Flutter Web) olarak build eder ve
# VPS üzerindeki canlı dizine rsync ile yükler. Caddy bu dizini filesystem üzerinden
# servis ettiği için container restart gerekmez — değişiklik anında etkindir.
#
# Kullanım:
#   ./deploy/scripts/deploy-cloud-frontend.sh
#
# Yapılandırma (env veya `deploy/.deploy-config` dosyası):
#   QUICKSERVE_DEPLOY_HOST    VPS adresi (örn. qrserve.co veya 165.245.214.173)
#   QUICKSERVE_DEPLOY_USER    SSH kullanıcı (varsayılan: root)
#   QUICKSERVE_DEPLOY_PATH    Hedef dizin (varsayılan: /opt/quickserve)
#   QUICKSERVE_DEPLOY_URL     Smoke test URL (varsayılan: https://qrserve.co)
#   QUICKSERVE_SKIP_BUILD     1 yaparsan build adımını atlar (sadece rsync)
#   QUICKSERVE_AUTO_YES       1 yaparsan onay sormaz
#
# .deploy-config örneği (deploy/.deploy-config — gitignore'a eklenmeli):
#   QUICKSERVE_DEPLOY_HOST=qrserve.co
#   QUICKSERVE_DEPLOY_USER=root
#   QUICKSERVE_DEPLOY_PATH=/opt/quickserve
#   QUICKSERVE_DEPLOY_URL=https://qrserve.co
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/deploy/.deploy-config"

# --- Renkli çıktı yardımcıları ---
if [[ -t 1 ]]; then
	CLR_RESET=$'\033[0m'
	CLR_BOLD=$'\033[1m'
	CLR_RED=$'\033[31m'
	CLR_GREEN=$'\033[32m'
	CLR_YELLOW=$'\033[33m'
	CLR_BLUE=$'\033[34m'
	CLR_DIM=$'\033[2m'
else
	CLR_RESET=""; CLR_BOLD=""; CLR_RED=""; CLR_GREEN=""; CLR_YELLOW=""; CLR_BLUE=""; CLR_DIM=""
fi

step() { printf "\n%s==> %s%s\n" "$CLR_BLUE$CLR_BOLD" "$1" "$CLR_RESET"; }
ok()   { printf "  %s✓%s %s\n" "$CLR_GREEN" "$CLR_RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$CLR_YELLOW" "$CLR_RESET" "$1"; }
err()  { printf "  %s✗%s %s\n" "$CLR_RED" "$CLR_RESET" "$1" >&2; }
dim()  { printf "  %s%s%s\n" "$CLR_DIM" "$1" "$CLR_RESET"; }

# --- Config yükle ---
if [[ -f "$CONFIG_FILE" ]]; then
	# shellcheck disable=SC1090
	source "$CONFIG_FILE"
fi

HOST="${QUICKSERVE_DEPLOY_HOST:-}"
USER_NAME="${QUICKSERVE_DEPLOY_USER:-root}"
REMOTE_PATH="${QUICKSERVE_DEPLOY_PATH:-/opt/quickserve}"
SMOKE_URL="${QUICKSERVE_DEPLOY_URL:-}"
SKIP_BUILD="${QUICKSERVE_SKIP_BUILD:-0}"
AUTO_YES="${QUICKSERVE_AUTO_YES:-0}"

if [[ -z "$HOST" ]]; then
	err "QUICKSERVE_DEPLOY_HOST tanımlı değil."
	echo
	dim "Şu yollardan biriyle ayarlayabilirsin:"
	dim "  1) export QUICKSERVE_DEPLOY_HOST=qrserve.co"
	dim "  2) $CONFIG_FILE dosyasına yaz:"
	dim "       QUICKSERVE_DEPLOY_HOST=qrserve.co"
	dim "       QUICKSERVE_DEPLOY_USER=root"
	exit 1
fi

if [[ -z "$SMOKE_URL" ]]; then
	# Host bir IP değilse https://<host>, IP ise atla
	if [[ "$HOST" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
		SMOKE_URL=""
	else
		SMOKE_URL="https://$HOST"
	fi
fi

# --- Önkoşulları kontrol et ---
step "Önkoşullar kontrol ediliyor"
need_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		err "$1 komutu bulunamadı."
		exit 1
	fi
	ok "$1"
}
need_cmd rsync
need_cmd ssh
if [[ "$SKIP_BUILD" != "1" ]]; then
	need_cmd flutter
fi
if [[ -n "$SMOKE_URL" ]]; then
	need_cmd curl
fi

# --- SSH bağlantı testi ---
step "SSH bağlantısı doğrulanıyor ($USER_NAME@$HOST)"
if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$USER_NAME@$HOST" "true" 2>/dev/null; then
	err "SSH bağlanılamadı. Anahtar / authorized_keys / port-forwarding'i kontrol et."
	exit 1
fi
ok "SSH bağlandı"

# --- Hedef dizini doğrula ---
step "VPS hedef dizini doğrulanıyor ($REMOTE_PATH)"
if ! ssh "$USER_NAME@$HOST" "test -d '$REMOTE_PATH'"; then
	err "Hedef dizin yok: $REMOTE_PATH"
	dim "Kontrol et: ssh $USER_NAME@$HOST 'ls $REMOTE_PATH'"
	exit 1
fi
ok "Hedef dizin mevcut"

# --- Build ---
if [[ "$SKIP_BUILD" == "1" ]]; then
	warn "QUICKSERVE_SKIP_BUILD=1 — build atlandı, mevcut build/web kullanılacak"
else
	step "cloud_frontend Flutter Web build başlatılıyor"
	cd "$REPO_ROOT/cloud_frontend"
	flutter pub get >/dev/null
	flutter build web --release --dart-define=CLOUD_BASE_URL= 2>&1 | tail -20
	cd "$REPO_ROOT"
	ok "Build bitti: cloud_frontend/build/web"
fi

# --- Build çıktısı sağlığını kontrol et ---
WEB_DIR="$REPO_ROOT/cloud_frontend/build/web"
if [[ ! -f "$WEB_DIR/index.html" ]]; then
	err "Build çıktısı bulunamadı: $WEB_DIR/index.html"
	exit 1
fi
WEB_SIZE_MB=$(du -sm "$WEB_DIR" | awk '{print $1}')
WEB_FILE_COUNT=$(find "$WEB_DIR" -type f | wc -l | tr -d ' ')
ok "Build hazır: ${WEB_FILE_COUNT} dosya, ${WEB_SIZE_MB} MB"

# --- Onay ---
echo
printf "%s%s\n" "$CLR_BOLD" "Aktarım özeti:"
printf "%s\n" "$CLR_RESET"
printf "  Kaynak     : %s\n" "$WEB_DIR/"
printf "  Hedef      : %s@%s:%s/cloud_frontend/build/web/\n" "$USER_NAME" "$HOST" "$REMOTE_PATH"
printf "  Smoke test : %s\n" "${SMOKE_URL:-(atlanacak)}"
printf "  Build      : %s dosya, %s MB\n" "$WEB_FILE_COUNT" "$WEB_SIZE_MB"
echo

if [[ "$AUTO_YES" != "1" ]]; then
	read -r -p "Devam et? [y/N] " ans
	if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
		warn "Kullanıcı tarafından iptal edildi"
		exit 1
	fi
fi

# --- rsync ---
step "rsync ile yükleniyor"
REMOTE_WEB_DIR="$REMOTE_PATH/cloud_frontend/build/web"
ssh "$USER_NAME@$HOST" "mkdir -p '$REMOTE_WEB_DIR'"
# macOS'in BSD rsync'i --info=progress2 desteklemiyor; --progress yeterli.
rsync -avz --delete --progress \
	"$WEB_DIR/" \
	"$USER_NAME@$HOST:$REMOTE_WEB_DIR/"
ok "Yükleme tamam"

# --- Caddy filesystem tarafından servis ediyor — restart gerekmez ---
# Yine de browser cache'i bypass için Caddy'i reload edebilmek opsiyonel.
step "Caddy bilgisi"
dim "Caddy build/web dizinini read-only mount eder, yeni dosyalar anında servise girer."
dim "Cache temizlemek istersen: ssh $USER_NAME@$HOST 'cd $REMOTE_PATH/deploy/cloud && docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile'"

# --- Smoke test ---
if [[ -n "$SMOKE_URL" ]]; then
	step "Smoke test: $SMOKE_URL"
	HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" -L --max-time 15 "$SMOKE_URL/" || echo "000")
	if [[ "$HTTP_CODE" == "200" ]]; then
		ok "HTTP 200 — frontend yayında"
	else
		warn "HTTP $HTTP_CODE — beklenen 200, manuel kontrol et"
	fi
	# index.html son değişiklik zamanı
	LAST_MOD=$(curl -sSI --max-time 10 "$SMOKE_URL/" | awk -F': ' '/^[Ll]ast-[Mm]odified/ {print $2}' | tr -d '\r')
	if [[ -n "$LAST_MOD" ]]; then
		dim "index.html Last-Modified: $LAST_MOD"
	fi
fi

echo
printf "%s%sDeploy başarılı.%s\n" "$CLR_GREEN" "$CLR_BOLD" "$CLR_RESET"
if [[ -n "$SMOKE_URL" ]]; then
	dim "Tarayıcıda $SMOKE_URL aç ve hard reload yap (Cmd+Shift+R / Ctrl+Shift+R)."
else
	dim "Tarayıcıda VPS URL'sini aç ve hard reload yap (Cmd+Shift+R / Ctrl+Shift+R)."
fi
