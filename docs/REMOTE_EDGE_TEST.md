# QuickServe — Uzaktaki Bir Arkadaş İçin Edge Kurulum Playbook'u

**Son güncelleme:** 2026-05-26
**Senaryo:** Uzaktaki birinin (farklı ev/şehir) bilgisayarına test amaçlı Edge kurmak. Senin Cloud'un (`qrserve.co`) zaten yayında — arkadaşının Edge'i Cloudflare Named Tunnel üzerinden Cloud'a bağlanır.

İlgili belgeler:
- [NEW_RESTAURANT_ONBOARDING.md](./NEW_RESTAURANT_ONBOARDING.md) — Gerçek restoran kurulumunun tam playbook'u
- [DEPLOY_TEST.md](./DEPLOY_TEST.md) — İlk deploy detayı
- [deploy/edge/cloudflared/README.md](../deploy/edge/cloudflared/README.md) — Cloudflare Tunnel detayı

---

## 🎯 Senaryo özeti

| Konu | Detay |
|---|---|
| **Arkadaşın bilgisayarı** | Mac / Linux / Windows + Docker kurulu (kurulacak) |
| **Network** | Farklı ev/şehir, NAT arkasında (sorun değil — Cloudflare Tunnel zaten bunun için) |
| **Amaç** | Edge ayağa kalksın, Cloud (`qrserve.co`) ile konuşsun, sen telefondan QR okutup test edebilesin |
| **Senin Cloud'un** | `qrserve.co` zaten yayında, hiç değişiklik yok |

**Mimari görünüm:**

```
Senin telefonun         Senin VPS'in              Arkadaşın bilgisayarı
(İstanbul)              (qrserve.co)               (örn. Ankara)
     │                       │                            │
     │── QR scan ────────────►                            │
     │◄── menü ───────────────│── Cloudflare Tunnel ─────►│ (Edge + Postgres)
                              │   (edge-ahmet.qrserve.co)│
                              │                            │
   senin süperadmin paneli ──►│                            │
   (restoran ONLINE)          │                            │
```

---

## 🔵 SEN ne yapacaksın (45 dk — ofiste)

### A1. Cloud'da test restoranı oluştur (5 dk)

```
1. https://qrserve.co → admin@qrserve.co / 1 ile login
2. "Restoranlar" → "Yeni Restoran"
3. İsim: "Test Restoran - Ahmet" (arkadaşının adı)
4. Kaydet → çıkan UUID'yi kopyala
   → bu QUICKSERVE_RESTAURANT_ID olacak
```

### A2. Restoran admin kullanıcı oluştur (3 dk)

Arkadaşın da panel görsün diye:

```
1. Restoran detayında "Kullanıcılar" → "Yeni"
2. Email: ahmet@test.com
3. Şifre: geçici (örn. "Test1234!")
4. Rol: RESTAURANT_ADMIN
```

### A3. Cloudflare Named Tunnel oluştur (10 dk)

```
1. dash.cloudflare.com → Zero Trust → Networks → Tunnels
2. "Create a tunnel" → Cloudflared seç
3. İsim: quickserve-edge-ahmet
4. Çıkan "Docker" sekmesinde token'ı kopyala (eyJh... ile başlayan uzun string)
   → bu CLOUDFLARED_TUNNEL_TOKEN
5. "Public Hostname" sekmesi → ADD HOSTNAME:
   - Subdomain: edge-ahmet
   - Domain: qrserve.co
   - Service Type: HTTP
   - URL: edge:8081
6. Save
7. DNS sekmesinden kontrol: edge-ahmet.qrserve.co CNAME görünmeli
```

> **Token = Tunnel kimliği.** Cloudflared container'ı bu token ile çalıştığında, Cloudflare'e "ben tunnel X'in connector'üyüm" der ve oluşturduğun tunnel'a bağlanır. Hangi makinede çalıştığı önemli değil — token nereye yapıştırsan o makine bu tunnel'ın bir bacağı olur.

### A4. Self-contained Edge bundle build et — tek `.tar.gz` (10-15 dk)

Arkadaşının ne Flutter ne Maven kurmasına, hatta **git clone'a bile** gerek var; sen lokalde edge backend + frontend gömülü Caddy imajlarını + compose + Caddyfile + install scriptini **tek pakete** koyarsın.

```bash
cd ~/Desktop/projects/quickserve

# Linux x86_64 VM/PC için (en yaygın):
./deploy/scripts/build-edge-images.sh --tag v0.1.0 --platform linux/amd64

# Raspberry Pi / ARM mini PC için:
./deploy/scripts/build-edge-images.sh --tag v0.1.0 --platform linux/arm64
```

Çıktı: `/tmp/quickserve-edge-bundle-v0.1.0.tar.gz` (≈190 MB) + `.sha256`. İçinde:

```
images/edge.tar              ← Backend imajı
images/edge-caddy.tar        ← Caddy + Flutter Web (frontend gömülü)
deploy/docker-compose.yml    ← Compose dosyası (image: + build: hibrit)
deploy/Caddyfile             ← Caddy konfig (referans; imajda zaten gömülü)
deploy/.env.example          ← .env şablonu (EDGE_TAG=v0.1.0 dahil)
install.sh                   ← Edge cihazında tek komutla kurulum
VERSION                      ← Bundle metadata
```

> **Neden bundle?** Edge cihazının interneti/diski/işlemcisi zayıf olabilir. Edge'de **ne `git pull`, ne `docker build`** gerekir. Sadece `tar -xzf` + `install.sh`. Flutter SDK pull yok, Maven download yok, kod tabanı klonu yok.

### A5. Arkadaşa "kurulum kiti" hazırla (10 dk)

Yerel makinende komut:

```bash
# Yeni Edge UUID
echo "QUICKSERVE_EDGE_ID=$(uuidgen)"

# Yeni Postgres password
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)"

# Yeni JWT secret
echo "QUICKSERVE_JWT_SECRET=$(openssl rand -base64 48)"
```

Bu çıktıları arkadaşa göndereceğin `.env` dosyasının içine koy:

```env
EDGE_LAN_HOSTNAME=edge.local

QUICKSERVE_CLOUD_BASE_URL=https://qrserve.co
QUICKSERVE_PUBLIC_CLOUD_URL=https://qrserve.co

QUICKSERVE_EDGE_ID=<yukarıdaki uuidgen çıktısı>
QUICKSERVE_RESTAURANT_ID=<A1'de kopyaladığın restoran UUID'si>

QUICKSERVE_PUBLIC_EDGE_URL=https://edge-ahmet.qrserve.co

CLOUDFLARED_TUNNEL_TOKEN=<A3'te kopyaladığın token>

POSTGRES_DB=quickserve_edge
POSTGRES_USER=quickserve
POSTGRES_PASSWORD=<openssl rand çıktısı>

QUICKSERVE_JWT_SECRET=<openssl rand çıktısı>

QUICKSERVE_GUEST_LAB_ENABLED=false
QUICKSERVE_MEDIA_MAX_IMAGE_BYTES=5242880
```

**Kit içeriği:**

| Dosya | Açıklama |
|---|---|
| `.env` | Yukarıda doldurduğun (en hassas — Signal/Bitwarden ile gönder) |
| `quickserve-edge-bundle-v0.1.0.tar.gz` + `.sha256` | A4'te ürettiğin bundle (≈190 MB; içinde imajlar + compose + install.sh) |
| Bu doküman | Arkadaş kurulum talimatı olarak okur |

### A6. Kit'i güvenli kanaldan gönder (5 dk)

- `.env` → **mutlaka şifreli kanal**: Signal / WhatsApp ucu-uca / Bitwarden Send / parolalı zip
- Diğer dosyalar normal kanal (Google Drive, WeTransfer)
- ❌ E-posta ile `.env` gönderme (token sızdırır)

---

## 🟠 ARKADAŞIN ne yapacak (45 dk – ilk seferde 1 saat)

### B1. Docker kur (10-30 dk, OS'a bağlı)

**Mac:**
- https://www.docker.com/products/docker-desktop/ → Docker Desktop indir
- Kur, aç, tray icon'da yeşil "Engine running" görmeli

**Windows:**
- Docker Desktop indir + WSL2 aktif et
- Komutları WSL2 Ubuntu terminalinde çalıştırmak daha sorunsuz

**Linux (Ubuntu):**
```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git unzip
sudo usermod -aG docker $USER
# logout / login
```

**Test:** `docker run hello-world` → başarılı çıktı görmeli.

### B2-B4. Bundle'ı aç ve kur (5-10 dk)

```bash
# (1) Bundle ve .env'i bir yere koy
mkdir -p ~/quickserve-install && cd ~/quickserve-install
mv ~/Downloads/quickserve-edge-bundle-v0.1.0.tar.gz* .

# (2) Hash doğrula
sha256sum -c quickserve-edge-bundle-v0.1.0.tar.gz.sha256   # OK görmeli

# (3) Aç
tar -xzf quickserve-edge-bundle-v0.1.0.tar.gz
cd quickserve-edge-bundle-v0.1.0

# (4) İlk kurulum — imajları yükle, compose dosyalarını /opt/quickserve'e koy,
# .env'i .env.example'dan oluştur (henüz placeholder değerler).
sudo bash install.sh

# (5) .env'i editle: arkadaşın gönderdiği değerleri yapıştır
sudo nano /opt/quickserve/deploy/edge/.env
# - QUICKSERVE_EDGE_ID, QUICKSERVE_RESTAURANT_ID
# - CLOUDFLARED_TUNNEL_TOKEN
# - POSTGRES_PASSWORD, QUICKSERVE_JWT_SECRET, QUICKSERVE_SYNC_SHARED_SECRET
# - QUICKSERVE_PUBLIC_EDGE_URL
# (EDGE_TAG zaten doğru ayarlanmış olacak; install.sh otomatik set ediyor)
```

### B5. Servisleri başlat (1-2 dk — build YOK)

```bash
cd ~/quickserve-install/quickserve-edge-bundle-v0.1.0
sudo bash install.sh --start

# Veya manuel:
cd /opt/quickserve/deploy/edge && docker compose up -d
```

İlerleme:
```bash
cd /opt/quickserve/deploy/edge
docker compose logs -f edge
```

Şu satırı görmeli (~30 sn sonra; build olmadığı için çok hızlı): `Started EdgeApplication in 12.3 seconds`

### B6. Sağlık kontrolü (2 dk)

```bash
docker compose ps  # 4 servis "Up"
docker compose logs cloudflared | grep -i "connection registered"  # 4 satır normal
curl -s http://localhost/api/v1/edge/info  # JSON dönmeli
```

### B8. Sana haber ver

> "Edge ayakta, 4 container çalışıyor, /api/v1/edge/info JSON dönüyor."

---

## 🟢 BİRLİKTE doğrulama (15 dk)

### C1. Sen — Cloud panelden doğrula

```
1. https://qrserve.co → süperadmin login
2. "Restoranlar" → "Test Restoran - Ahmet"
3. Edge kartı: ONLINE ✅
4. Son hello: 1-2 dakika içinde
5. Public Edge URL: https://edge-ahmet.qrserve.co
```

### C2. Sen — Senin tarafından Edge'e erişim testi

```bash
# Senin makinende
curl -sS https://edge-ahmet.qrserve.co/api/v1/edge/info
# Beklenen: JSON, edgeId arkadaşın .env'indeki ile aynı
```

### C3. Birlikte — Restoran admin login

Arkadaşın LAN içinden test edebilir:
- `http://localhost/` → restoran admin login ekranı
- `ahmet@test.com / Test1234!` → girer

### C4. Birlikte — Uçtan uca QR testi

```
1. Cloud admin'den 1 masa için QR PDF üret
2. QR'ı arkadaşın ekranında göster
3. Sen telefondan oku
4. Menü açılır, garson çağır → arkadaşın garson sayfasında bildirim
5. Sipariş gönder → arkadaşın garson sayfasında masa görünür
```

---

## ⚠️ Olası sorunlar ve çözümler

| Sorun | Tespit | Çözüm |
|---|---|---|
| `docker compose up` "permission denied" | Docker group'a eklenmedi | `sudo usermod -aG docker $USER` + logout/login |
| Edge build çok uzun (>30 dk) | İnternet yavaş veya disk dolu | `df -h` kontrol, hızlı internete geç |
| Cloudflared "tunnel not found" | Token yanlış kopyalanmış | `.env` token'ı kontrol, fazladan boşluk yok mu? |
| `edge-ahmet.qrserve.co` 530 hatası | Public Hostname kaydedilmemiş | Cloudflare panelinde A3-5 adımını tekrarla |
| Cloud panel Edge OFFLINE | Hello gitmiyor | Arkadaşın: `docker compose logs edge \| grep -i hello` |
| QR okuyunca "restoran offline" | Edge tunnel ile Cloud bağlantısı yok | C2 testi (curl) — başarısızsa cloudflared restart |
| `localhost` açılınca 502 | Caddy edge'e ulaşamıyor (henüz başlamamış) | 1-2 dk bekle, sonra `docker compose restart caddy` |
| Mac/Windows port 80 dolu | Apache/IIS varsa çakışır | `docker-compose.yml`'de Caddy `80:80` → `8080:80` yap, `http://localhost:8080` kullan |

---

## 🔍 Cloudflare Tunnel — `edge-ahmet.qrserve.co` arkadaşın bilgisayarına nasıl bağlanıyor?

İlk başta "büyü" gibi görünür. Aslında 3 parçanın anlaşması:

### Parça 1: DNS — Cloudflare'in "kapısı"

Cloudflare panelinde public hostname eklediğinde DNS'e otomatik bir CNAME yazıldı:

```
edge-ahmet.qrserve.co  CNAME  <tunnel-id>.cfargotunnel.com
                                        ↑
                                        senin tunnel ID'in
                                        (token içinde gömülü)
```

Bu CNAME, "bu hostname'e gelen istekleri Cloudflare'in `cfargotunnel.com` altyapısına yolla" demek. Yani **istek önce Cloudflare'in kendi sunucularına gelir**, doğrudan arkadaşın bilgisayarına gitmez.

### Parça 2: Token — Connector'ün kimlik kartı

Cloudflare'de tunnel oluşturduğunda sana bir **token** verdi. Bu token, base64 ile encode edilmiş bir JSON. Açtığında içinde:

```json
{
  "a": "<account-id>",
  "t": "<tunnel-id>",      ← hangi tunnel
  "s": "<secret>"          ← bu tunnel için imza secret'ı
}
```

Token = "Ben tunnel X'in connector'üyüm, secret Y" demenin kısaca yazılı hali. Sen bunu `.env`'e yapıştırınca, arkadaşın `cloudflared` container'ı bu kimlikle Cloudflare'e bağlanır.

### Parça 3: Reverse Tunnel — Outbound bağlantı kurma

Bu kritik kısım. Arkadaşının bilgisayarı NAT arkasında, dışarıdan erişilemez. Ama **dışarıya çıkabilir**.

Arkadaşın `docker compose up -d` çalıştırınca `cloudflared` container'ı şunu yapar:

```
1. Token'ı okur, tunnel ID + secret çıkarır
2. Cloudflare'in edge node'larına HTTPS bağlantısı açar (outbound, port 443)
3. "Selam, ben tunnel <id>'in connector'üyüm, secret <s>" der
4. Cloudflare onaylar, bağlantıyı AÇIK TUTAR (long-lived QUIC/HTTP2)
5. 4 farklı Cloudflare datacenter'a bağlanır (HA için)
```

Bu adımdan sonra Cloudflare'in elinde **arkadaşın bilgisayarına geri konuşabileceği canlı bir kanal** var.

### Tüm akış — bir istek geldiğinde

Şimdi sen telefondan `https://edge-ahmet.qrserve.co/api/v1/edge/info` yazınca:

```
1. Telefon DNS sorgular
   → edge-ahmet.qrserve.co CNAME → <tunnel-id>.cfargotunnel.com → Cloudflare IP
   
2. İstek Cloudflare'in en yakın datacenter'ına gider (örn. İstanbul edge)

3. Cloudflare içeride bakar: "Bu hostname hangi tunnel'a ait?"
   → Token'ın <tunnel-id>'si ile public hostname kaydı eşleşir
   → "Aha, bu tunnel'ın connector'üne yollayayım"

4. Cloudflare, AÇIK olan o uzun ömürlü bağlantı üzerinden isteği arkadaşın
   bilgisayarındaki cloudflared container'a iletir.

5. Cloudflared container, Docker compose ağındadır. Public hostname tanımında
   service URL olarak "edge:8081" yazmıştık. Cloudflared docker network'te
   "edge" servis adını çözer, 8081 portuna HTTP isteği gönderir.

6. Edge Spring Boot uygulaması cevap üretir → cloudflared'e döner → tunnel
   üzerinden Cloudflare'e gider → telefonuna ulaşır.
```

### Görsel akış

```
                     ┌─────────────────────────────────────────┐
                     │     CLOUDFLARE'IN AĞI (her yerde)        │
   Senin telefon     │  ┌──────────────┐    ┌──────────────┐   │  Arkadaşın bilgisayarı
        │            │  │ DNS resolver │    │  Edge nodes  │   │       (NAT arkası)
        │            │  └──────┬───────┘    └──────┬───────┘   │            │
        │            │         │ CNAME             │           │            │
        │            │         │ edge-ahmet →      │ uzun     │            │
        │ HTTPS      │         │ tunnel-id.cfargo  │ ömürlü   │  cloudflared│
        │ GET ───────┼────────►│                   │ tunnel   │◄─ container │
        │ /api/info  │         └─→ tunnel-id'ye yolla         │   (Docker)  │
        │            │             │                          │     │       │
        │            │             └──────────────────────────┼─────┘       │
        │            │                                        │     │       │
        │            │                                        │     ▼       │
        │            │                                        │ ┌──────┐    │
        │            │                                        │ │ edge │    │
        │ ◄──────────┼────────────────────────────────────────┼─┤ :8081│    │
        │  JSON      │             cevap geri tunnel'dan      │ └──────┘    │
                     └─────────────────────────────────────────┘
```

### Anlaşılması gereken kritik kavramlar

1. **Token = tunnel'a sahiplik belgesi.** Hangi makinede çalıştırsan o makine bu tunnel'ın bir bacağı olur. Token'ı başka birine versen, o da aynı tunnel'a bağlanır (yani **token'ı koru!**).

2. **Hiçbir port açmadın.** Arkadaşının router'ında port forward, firewall kuralı yok. Çünkü bağlantı arkadaşının bilgisayarından **dışarıya** kuruluyor (outbound 443/HTTPS). Bu güvenlik açısından harika — restoran sahibinin router'ında hiçbir şey değiştirmiyorsun.

3. **DNS Cloudflare'de, container istediğin yerde.** DNS kaydını sen oluşturdun (`edge-ahmet.qrserve.co`), ama tunnel connector'ünü arkadaşın çalıştırdı. İkisi token sayesinde birbirini bulur.

4. **Service URL `edge:8081` arkadaşın Docker network'ünde çözülür.** Cloudflared container ile Edge container aynı `docker-compose` ağında olduğu için, cloudflared "edge" host'unu Docker DNS'i ile çözer. Senin Cloudflare panelindeki ayar **container'ın içinde** çalışır, dışarıdan ulaşılabilirlik gerekmez.

5. **Tek bağlantı, çift yönlü trafik.** Cloudflared bir kez bağlanır (HTTP/2 multiplexed), Cloudflare bu bağlantı üzerinden istediği kadar istek gönderebilir. Yeni istek için yeni bağlantı kurulmaz.

### Tunnel'ı taşıma testi (faydalı denemek için)

Arkadaşının `.env`'indeki tokenı **senin** kendi laptop'una alıp `cloudflared` container'ı orada çalıştırırsan, **`edge-ahmet.qrserve.co` artık senin laptop'una gelen istekleri yönlendirir.** Hiçbir DNS/IP değişikliği gerekmez. Tunnel'ın "bacağı" sadece **nerede cloudflared çalışıyorsa orası**.

Bu yüzden bir Edge bilgisayarı bozulursa:
1. Yeni cihaza aynı `.env` (aynı token, aynı UUID) konur
2. Aynı backup restore edilir
3. Cihaz açılır, cloudflared aynı tunnel'a bağlanır
4. **Dışarıdan hiçbir değişiklik gerekmez** — DNS bile değişmez. Müşteriler ve Cloud aynı hostname'i kullanmaya devam eder.

Bu Cloudflare Tunnel'ın saha operasyonunda en güçlü tarafıdır.

---

## 📦 Sen şimdi neyi hazırlıyorsun (checklist)

```
☐ A1. Cloud'da test restoranı oluştur (UUID kaydet)
☐ A2. Restoran admin kullanıcı oluştur
☐ A3. Cloudflare Named Tunnel + edge-ahmet.qrserve.co
☐ A4. edge_frontend build + zip
☐ A5.a uuidgen + openssl ile yeni secret'lar üret
☐ A5.b .env dosyasını arkadaşın için doldur
☐ A5.c quickserve kod paketi (git archive veya repo invite)
☐ A6. Hepsini güvenli kanaldan gönder (Signal/Bitwarden)
☐ Arkadaşa bu talimatı da gönder
```

---

## 🚀 Tahmini zaman çizelgesi

| Adım | Süre | Kim |
|---|---|---|
| Sen — kit hazırlık | 45 dk | Sen |
| Arkadaşa kit aktarımı | 5 dk | Sen |
| Arkadaş — Docker kurulum | 10-30 dk | Arkadaş |
| Arkadaş — `docker compose up --build` | 15-25 dk | Arkadaş |
| Birlikte doğrulama | 15 dk | İkisi |
| **Toplam** | **~2 saat** | |

Bu süre sonunda arkadaşının makinesi senin filondaki ikinci Edge olur ve `qrserve.co` panelinden tek tıkla yönetebilirsin.
