#!/usr/bin/env bash
# deploy-cloud-stack.sh
# ---------------------------------------------------------------------------
# Cloud backend (Spring Boot) + frontend (Flutter Web) tek seferde deploy eder.
#
# Akış:
#   1. Yerelde cloud_frontend Flutter Web build
#   2. Kaynak kodu ve frontend build çıktısını VPS'e rsync (.env korunur)
#   3. VPS'te `docker compose up -d --build cloud` ile backend yeniden inşa
#   4. Yeni container sağlık beklemesi (max 90 sn)
#   5. Smoke test: frontend 200, backend 401/403 (auth bekliyor demek)
#
# Kullanım:
#   ./deploy/scripts/deploy-cloud-stack.sh
#
# Yapılandırma (env veya `deploy/.deploy-config`):
#   QUICKSERVE_DEPLOY_HOST    VPS adresi (örn. qrserve.co)
#   QUICKSERVE_DEPLOY_USER    SSH kullanıcı (varsayılan: root)
#   QUICKSERVE_DEPLOY_PATH    Hedef dizin (varsayılan: /opt/quickserve)
#   QUICKSERVE_DEPLOY_URL     Smoke test URL (varsayılan: https://$HOST)
#   QUICKSERVE_SKIP_BUILD     1 = frontend build atla
#   QUICKSERVE_SKIP_BACKEND   1 = backend rebuild atla (sadece frontend)
#   QUICKSERVE_AUTO_YES       1 = onay sorma
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
SKIP_BACKEND="${QUICKSERVE_SKIP_BACKEND:-0}"
AUTO_YES="${QUICKSERVE_AUTO_YES:-0}"

if [[ -z "$HOST" ]]; then
	err "QUICKSERVE_DEPLOY_HOST tanımlı değil."
	echo
	dim "Şu yollardan biriyle ayarlayabilirsin:"
	dim "  1) export QUICKSERVE_DEPLOY_HOST=qrserve.co"
	dim "  2) $CONFIG_FILE dosyasına yaz (örnek: deploy/.deploy-config.example)"
	exit 1
fi

if [[ -z "$SMOKE_URL" ]]; then
	if [[ "$HOST" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
		SMOKE_URL=""
	else
		SMOKE_URL="https://$HOST"
	fi
fi

# --- Önkoşullar ---
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
	err "SSH bağlanılamadı. Anahtar / authorized_keys / port-forwarding kontrol et."
	exit 1
fi
ok "SSH bağlandı"

# --- Hedef dizini doğrula ---
step "VPS hedef dizini doğrulanıyor ($REMOTE_PATH)"
if ! ssh "$USER_NAME@$HOST" "test -d '$REMOTE_PATH'"; then
	err "Hedef dizin yok: $REMOTE_PATH"
	exit 1
fi
if ! ssh "$USER_NAME@$HOST" "test -f '$REMOTE_PATH/deploy/cloud/.env'"; then
	warn ".env dosyası VPS'te yok: $REMOTE_PATH/deploy/cloud/.env"
	warn "Backend başlamayabilir. Devam etmeden önce kontrol et."
fi
ok "Hedef dizin mevcut"

# --- Frontend build ---
if [[ "$SKIP_BUILD" == "1" ]]; then
	warn "QUICKSERVE_SKIP_BUILD=1 — frontend build atlandı"
else
	step "cloud_frontend Flutter Web build başlatılıyor"
	cd "$REPO_ROOT/cloud_frontend"
	flutter pub get >/dev/null
	flutter build web --release --dart-define=CLOUD_BASE_URL= 2>&1 | tail -15
	cd "$REPO_ROOT"
	ok "Frontend build bitti"
fi

WEB_DIR="$REPO_ROOT/cloud_frontend/build/web"
if [[ ! -f "$WEB_DIR/index.html" ]]; then
	err "Build çıktısı yok: $WEB_DIR/index.html (önce build et veya QUICKSERVE_SKIP_BUILD=0)"
	exit 1
fi

# --- Onay ---
echo
printf "%s%sAktarım özeti:%s\n" "$CLR_BOLD" "" "$CLR_RESET"
printf "  Backend rebuild : %s\n" "$([ "$SKIP_BACKEND" == "1" ] && echo 'HAYIR (atlandı)' || echo 'EVET')"
printf "  Frontend rsync  : EVET\n"
printf "  Kaynak repo     : %s\n" "$REPO_ROOT"
printf "  Hedef           : %s@%s:%s\n" "$USER_NAME" "$HOST" "$REMOTE_PATH"
printf "  Smoke test      : %s\n" "${SMOKE_URL:-(atlanacak)}"
echo

if [[ "$AUTO_YES" != "1" ]]; then
	read -r -p "Devam et? [y/N] " ans
	if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
		warn "İptal edildi"
		exit 1
	fi
fi

# --- rsync: kaynak kodu ---
if [[ "$SKIP_BACKEND" != "1" ]]; then
	step "Backend kaynak kodu rsync (.env korunur)"
	# Ortak excludes
	RSYNC_EXCLUDES=(
		--exclude='target/'
		--exclude='build/'
		--exclude='.idea/'
		--exclude='.vscode/'
		--exclude='*.iml'
		--exclude='*.class'
		--exclude='.DS_Store'
		--exclude='.env'
		--exclude='**/.env'
		--exclude='.deploy-config'
	)
	# Backend için gerekli dosyalar
	rsync -avz --delete \
		"${RSYNC_EXCLUDES[@]}" \
		"$REPO_ROOT/pom.xml" \
		"$USER_NAME@$HOST:$REMOTE_PATH/"
	rsync -avz --delete \
		"${RSYNC_EXCLUDES[@]}" \
		"$REPO_ROOT/common/" \
		"$USER_NAME@$HOST:$REMOTE_PATH/common/"
	rsync -avz --delete \
		"${RSYNC_EXCLUDES[@]}" \
		"$REPO_ROOT/cloud/" \
		"$USER_NAME@$HOST:$REMOTE_PATH/cloud/"
	# Edge için sadece pom.xml lazım (Dockerfile reactor build için okur)
	ssh "$USER_NAME@$HOST" "mkdir -p '$REMOTE_PATH/edge'"
	rsync -avz \
		"$REPO_ROOT/edge/pom.xml" \
		"$USER_NAME@$HOST:$REMOTE_PATH/edge/pom.xml"
	# Deploy dosyaları (Dockerfile, Caddyfile, compose) — .env hariç
	rsync -avz \
		"${RSYNC_EXCLUDES[@]}" \
		"$REPO_ROOT/deploy/cloud/" \
		"$USER_NAME@$HOST:$REMOTE_PATH/deploy/cloud/"
	ok "Backend kaynak yüklendi (.env dokunulmadı)"
fi

# --- rsync: frontend build ---
step "Frontend build/web rsync"
ssh "$USER_NAME@$HOST" "mkdir -p '$REMOTE_PATH/cloud_frontend/build/web'"
# macOS'in BSD rsync'i --info=progress2 desteklemiyor; --progress yeterli.
rsync -avz --delete --progress \
	"$WEB_DIR/" \
	"$USER_NAME@$HOST:$REMOTE_PATH/cloud_frontend/build/web/"
ok "Frontend yüklendi"

# --- Backend rebuild ---
if [[ "$SKIP_BACKEND" == "1" ]]; then
	warn "QUICKSERVE_SKIP_BACKEND=1 — backend rebuild atlandı"
	dim "Frontend canlıda ama backend eski kodla çalışıyor olabilir."
else
	step "VPS üzerinde backend yeniden inşa (docker compose --build cloud)"
	ssh "$USER_NAME@$HOST" "cd '$REMOTE_PATH/deploy/cloud' && docker compose up -d --build cloud" 2>&1 | tail -20
	ok "Backend yeniden inşa komutu gönderildi"

	# --- Container sağlık bekle ---
	step "Cloud container hazır olması bekleniyor (max 90 sn)"
	for i in {1..18}; do
		STATE=$(ssh "$USER_NAME@$HOST" \
			"cd '$REMOTE_PATH/deploy/cloud' && docker compose ps cloud --format '{{.State}}' 2>/dev/null || echo none")
		if [[ "$STATE" == "running" ]]; then
			# Spring Boot içeride başlamış mı? logs'a bak
			LOGS=$(ssh "$USER_NAME@$HOST" \
				"cd '$REMOTE_PATH/deploy/cloud' && docker compose logs --tail=30 cloud 2>/dev/null | grep -c 'Started CloudApplication' || true")
			if [[ "$LOGS" -gt 0 ]]; then
				ok "Cloud uygulaması başlatıldı (${i}*5 = $((i*5)) sn)"
				break
			fi
		fi
		if [[ $i -eq 18 ]]; then
			warn "90 sn içinde 'Started CloudApplication' görülmedi. Log'a bak:"
			dim "ssh $USER_NAME@$HOST 'cd $REMOTE_PATH/deploy/cloud && docker compose logs --tail=80 cloud'"
		fi
		sleep 5
	done
fi

# --- Smoke test ---
if [[ -n "$SMOKE_URL" ]]; then
	step "Smoke test"

	HTTP_FE=$(curl -sS -o /dev/null -w "%{http_code}" -L --max-time 15 "$SMOKE_URL/" || echo "000")
	if [[ "$HTTP_FE" == "200" ]]; then
		ok "Frontend $SMOKE_URL/ → HTTP 200"
	else
		warn "Frontend $SMOKE_URL/ → HTTP $HTTP_FE (beklenen 200)"
	fi

	# Backend: auth gerektiren bir endpoint — 401 veya 403 dönerse server canlı demektir
	HTTP_BE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 15 "$SMOKE_URL/api/v1/admin/restaurants" || echo "000")
	case "$HTTP_BE" in
		401|403)
			ok "Backend $SMOKE_URL/api/v1/admin/restaurants → HTTP $HTTP_BE (auth bekliyor, server canlı)"
			;;
		200)
			ok "Backend → HTTP 200 (server canlı)"
			;;
		000)
			err "Backend cevap vermedi. Log'a bak."
			;;
		5*)
			err "Backend HTTP $HTTP_BE — uygulama henüz hazır değil veya hata."
			;;
		*)
			warn "Backend → HTTP $HTTP_BE (beklenmedik)"
			;;
	esac

	# Yeni endpoint var mı? Test (auth lazım ama 404 dönüyorsa endpoint hâlâ eski)
	HTTP_HC=$(curl -sS -o /dev/null -w "%{http_code}" -X POST --max-time 10 \
		"$SMOKE_URL/api/v1/admin/restaurants/00000000-0000-0000-0000-000000000000/edge-health-check" || echo "000")
	case "$HTTP_HC" in
		401|403)
			ok "Yeni endpoint /edge-health-check → HTTP $HTTP_HC (deploy başarılı, auth bekliyor)"
			;;
		404)
			warn "Yeni endpoint 404 döndü — backend henüz yeni kodu yüklememiş olabilir. 30 sn bekle, log'a bak."
			;;
		*)
			dim "Yeni endpoint → HTTP $HTTP_HC"
			;;
	esac
fi

echo
printf "%s%sDeploy tamamlandı.%s\n" "$CLR_GREEN" "$CLR_BOLD" "$CLR_RESET"
if [[ -n "$SMOKE_URL" ]]; then
	dim "Tarayıcıda $SMOKE_URL aç ve hard reload yap (Cmd+Shift+R / Ctrl+Shift+R)."
fi
dim "Süperadmin panelinde restoran kartında kalp ikonu (♡) görmelisin."
