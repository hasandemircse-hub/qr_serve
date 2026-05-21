# QuickServe — İlk Test Deploy Kılavuzu

**Son güncelleme:** 2026-05-21
**Hedef:** Cloud–Edge hibrit mimaride **ilk gerçek deploy**:
- Cloud bir VPS'te (Docker)
- Edge yerel bir makinede (Docker + Cloudflare Tunnel)
- `cloud_frontend` Cloud sunucusunda, `edge_frontend` Edge makinesinde

İlgili belgeler: [QUICKSERVE_PLAN.md](./QUICKSERVE_PLAN.md), [CLOUD_EDGE_INTERNET.md](./CLOUD_EDGE_INTERNET.md)

---

## 0. Ön koşullar

- **Cloud tarafı:** Linux VPS (root SSH), Docker + Docker Compose v2 kurulu.
- **Edge tarafı:** Mac / Linux bir makine. Docker Desktop veya Docker Engine + Compose v2.
- **DNS / TLS:** İki seçenek (aşağıya bkz. §0.1):
  - **A) Domainsiz hızlı test:** Cloud için `nip.io`, Edge için Cloudflare Quick Tunnel
    (`*.trycloudflare.com`) — domain ve Cloudflare hesabı gerektirmez.
  - **B) Üretim:** Kendi domain'in + Cloudflare named tunnel.
- **Local araçlar:** Flutter SDK ≥ 3.11, Java 21, Maven 3.9, `openssl`, `uuidgen`.

### 0.1 Hangi modu seçeyim?

| | A) Domainsiz | B) Üretim |
|---|------------------|-----------|
| Domain gerekli mi? | Hayır | Evet (Cloudflare'da yönetilen) |
| Cloudflare hesabı? | Gerekmez | Gerekli |
| Cloud hostname | `<vps-ip>.nip.io` | `cloud.example.com` |
| Edge hostname | `*.trycloudflare.com` (random) | `edge-r1.tunnel.example.com` (sabit) |
| Edge URL her restart'ta değişir mi? | **Evet** | Hayır |
| Maliyet | 0 | Domain bedeli (~30 TL/yıl) |
| Kullanım | İlk test / öğrenme | Saha |

Bu rehber **A) Domainsiz** akışı önceler; B) için farklılıklar §3.1 ve §6'da.

İhtiyaç olacak değerler (önceden hazırla):

| Değer | A) Domainsiz | B) Üretim |
|--------|---------------|-----------|
| Cloud hostname | `<vps-ip>.nip.io` | `cloud.example.com` |
| Edge tunnel hostname | Quick Tunnel verir (script otomatik) | `edge-r1.tunnel.example.com` |
| Restoran UUID | mevcut seed: `11111111-1111-...` | yeni / mevcut |
| Edge UUID | `uuidgen` çıktısı | `uuidgen` çıktısı |
| JWT secret (Cloud / Edge) | `openssl rand -base64 48` (ayrı ayrı) | aynı |
| PG password (Cloud / Edge) | güçlü rastgele | aynı |
| Cloudflare tunnel token | — (Quick Tunnel için gerekmez) | `eyJ...` (panelden kopyala) |

---

## 1. Repo yapısı (deploy)

```
deploy/
├── cloud/
│   ├── Dockerfile          # Spring Boot Cloud
│   ├── docker-compose.yml  # cloud + postgres + caddy
│   ├── Caddyfile           # API + cloud_frontend statik
│   └── .env.example
├── edge/
│   ├── Dockerfile          # Spring Boot Edge
│   ├── docker-compose.yml  # edge + postgres + caddy + cloudflared
│   ├── Caddyfile           # LAN reverse proxy + edge_frontend
│   ├── cloudflared/README.md
│   └── .env.example
└── scripts/
    ├── build-cloud-frontend.sh
    └── build-edge-frontend.sh
```

Backend profilleri: `cloud/.../application-prod.yml`, `edge/.../application-prod.yml`
(env değişkenlerinden bütün secret/URL'leri alır).

---

## 2. Cloud sunucu kurulumu

### 2.1 VPS hazırlık

```bash
ssh root@<vps-ip>
apt update && apt install -y docker.io docker-compose-plugin git
systemctl enable --now docker
```

### 2.2 Repoyu al

```bash
git clone <repo-url> /opt/quickserve
cd /opt/quickserve/deploy/cloud
cp .env.example .env
```

### 2.3 `.env` düzenle

```bash
nano .env
```

En azından şunları doldur:

| Anahtar | Örnek (A — domainsiz) | Örnek (B — üretim) |
|---------|------------------------|---------------------|
| `CLOUD_HOSTNAME` | `185.123.45.67.nip.io` | `cloud.example.com` |
| `QUICKSERVE_PUBLIC_CLOUD_URL` | `https://185.123.45.67.nip.io` | `https://cloud.example.com` |
| `POSTGRES_PASSWORD` | rastgele | rastgele |
| `QUICKSERVE_JWT_SECRET` | `openssl rand -base64 48` | aynı |

> **VPS IP'sini öğrenmek için:** `curl -4 ifconfig.me` (VPS içinde).

### 2.4 DNS

- **A) Domainsiz:** `nip.io` otomatik çözüyor, **hiçbir şey yapma**.
- **B) Üretim:** `A` kaydı `cloud.example.com` → VPS IP (Cloudflare proxy KAPALI; Let's Encrypt
  HTTP-01 challenge için 80 portuna direkt ulaşmalı).

### 2.5 cloud_frontend (Flutter Web) build

İlk deploy için bu adımı **yerel makinende** (Flutter kurulu) yap, sonra build çıktısını VPS'e gönder:

```bash
# yerelde
cd quickserve
./deploy/scripts/build-cloud-frontend.sh
rsync -avz cloud_frontend/build/web/ root@<vps-ip>:/opt/quickserve/cloud_frontend/build/web/
```

Alternatif: VPS'e Flutter kurup orada da çalıştırabilirsin (önerilmez — disk büyüsün diye).

### 2.6 Ayağa kaldır

```bash
cd /opt/quickserve/deploy/cloud
docker compose up -d --build
docker compose logs -f cloud
```

Beklenen: Flyway migration sonrası `Started CloudApplication`.

### 2.7 Doğrulama

```bash
# A) Domainsiz örnek
curl -I https://185.123.45.67.nip.io/
curl -s https://185.123.45.67.nip.io/api/v1/sync/watermark?edgeId=00000000-0000-0000-0000-000000000000

# B) Üretim örnek
curl -I https://cloud.example.com/
```

Beklenen yanıt: 200 (cloud_frontend index) ve sync watermark JSON. Tarayıcıdan
`https://<CLOUD_HOSTNAME>` → süperadmin login ekranı görmelisin.

### 2.8 İlk süperadmin (otomatik bootstrap)

Prod profili `migration-local` seed'ini yüklemez. Süperadmin oluşturmak için
Cloud her açılışta DB'ye bakar; süperadmin yoksa `.env`'deki değerlerle yaratır,
varsa hiçbir şey yapmaz (idempotent).

`.env` dosyasında bu blok olmalı:

```env
QUICKSERVE_BOOTSTRAP_SUPERADMIN_ENABLED=true
QUICKSERVE_BOOTSTRAP_SUPERADMIN_EMAIL=admin@quickserve.test
QUICKSERVE_BOOTSTRAP_SUPERADMIN_PASSWORD=ChangeMe123!
QUICKSERVE_BOOTSTRAP_SUPERADMIN_DISPLAY_NAME=Hasan
QUICKSERVE_BOOTSTRAP_RESTAURANT_NAME=Test Restoran
```

`docker compose up -d cloud` ile başlat. Log'da:

```
Superadmin bootstrap: restoran oluşturuldu name='Test Restoran' id=<uuid>
Superadmin bootstrap: süperadmin oluşturuldu email='admin@quickserve.test' id=<uuid>
```

İkinci açılışta (veya restart'ta):

```
Superadmin bootstrap: en az bir süperadmin zaten var, atlanıyor.
```

> Bootstrap env değerlerini olduğu gibi bırakabilirsin; her açılışta tekrar oluşturmaz.
> Sadece veritabanını sıfırlayıp baştan başlattığında yeniden yaratır.

`restaurantId`'yi log'dan veya panel'de "Restoranlar"dan kopyala — Edge `.env`'inde
`QUICKSERVE_RESTAURANT_ID` olarak kullanacağız.

Tarayıcıdan login:

- URL: `https://<CLOUD_HOSTNAME>`
- Email: `admin@quickserve.test`
- Şifre: `ChangeMe123!`

Restoran kartı görünmeli; "Edge: NEVER_SEEN" yazar (Edge daha kurulmadı).

---

## 3. Edge makine kurulumu

### 3.1 Tunnel modu seçimi

**A) Quick Tunnel (domainsiz, test).** Hiçbir kurulum yok; `cloudflared` Docker
konteyneri başlayınca random `*.trycloudflare.com` URL'i alır.

**B) Named Tunnel (üretim).** Detay: [`deploy/edge/cloudflared/README.md`](../deploy/edge/cloudflared/README.md)

1. Cloudflare Zero Trust → Networks → Tunnels → **Create a tunnel** (`quickserve-edge-r1`).
2. **Docker** sekmesinden token'ı kopyala (→ `.env` `CLOUDFLARED_TUNNEL_TOKEN`).
3. **Public Hostname** ekle: `edge-r1.tunnel.example.com` → HTTP → `edge:8081`.
4. `deploy/edge/docker-compose.yml` içindeki `cloudflared` `command`'ini named tunnel'a
   uyarla (dosyada yorum satırı olarak hazır).

### 3.2 Repoyu al

```bash
cd /opt
git clone <repo-url> quickserve
cd quickserve/deploy/edge
cp .env.example .env
```

### 3.3 `.env` düzenle

Önemli alanlar:

| Anahtar | A — Quick Tunnel | B — Named Tunnel |
|---------|-------------------|-------------------|
| `QUICKSERVE_CLOUD_BASE_URL` | `https://<CLOUD_HOSTNAME>` | `https://cloud.example.com` |
| `QUICKSERVE_PUBLIC_CLOUD_URL` | aynı | aynı |
| `QUICKSERVE_PUBLIC_EDGE_URL` | **boş bırak** (script doldurur) | `https://edge-r1.tunnel.example.com` |
| `QUICKSERVE_EDGE_ID` | `uuidgen` | `uuidgen` |
| `QUICKSERVE_RESTAURANT_ID` | seed UUID veya panelden oluşturduğun | aynı |
| `CLOUDFLARED_TUNNEL_TOKEN` | boş | Cloudflare'dan |
| `POSTGRES_PASSWORD`, `QUICKSERVE_JWT_SECRET` | güçlü rastgele | aynı |

> **Restoran kaydı:** §2.8'de init endpoint'i ile yarattığın `restaurantId`'yi
> `QUICKSERVE_RESTAURANT_ID` olarak kullan. Sonradan başka restoran eklemek istersen
> Cloud süperadmin panelinden "Restoran ekle" akışını kullan.

### 3.4 edge_frontend (Flutter Web) build

```bash
# yerelde Edge'i çalıştıracağın makinede
cd quickserve
./deploy/scripts/build-edge-frontend.sh
# Üretilen edge_frontend/build/web compose tarafından monte edilecek
```

### 3.5 Ayağa kaldır

#### A) Quick Tunnel (otomatik script)

```bash
cd quickserve/deploy/edge
docker compose build
../scripts/edge-quick-tunnel.sh
```

Script şunları yapar:
1. `cloudflared` ve `postgres`'i başlatır.
2. cloudflared logundan `https://*.trycloudflare.com` URL'sini yakalar.
3. `.env` içinde `QUICKSERVE_PUBLIC_EDGE_URL`'i bu URL ile günceller.
4. `edge` ve `caddy`'i bu env ile yeniden başlatır.

Sonra:

```bash
docker compose logs -f edge cloudflared
```

> **Restart durumu:** Container'lar yeniden başlatılırsa Quick Tunnel URL'si değişebilir.
> Bu durumda yine `../scripts/edge-quick-tunnel.sh` çalıştır.

#### B) Named Tunnel

```bash
cd quickserve/deploy/edge
docker compose up -d --build
docker compose logs -f edge cloudflared
```

Beklenen log satırları (her iki modda):
- `EdgeDiscoveryService` Cloud'a hello attı (Cloud log: `registered edge ...`).
- `cloudflared` connection registered.

### 3.6 Doğrulama

**1) Cloud sunucusundan Edge'e erişim:**

```bash
# A) Quick Tunnel: URL'i .env'den oku veya
grep QUICKSERVE_PUBLIC_EDGE_URL .env
curl -sS "$(grep QUICKSERVE_PUBLIC_EDGE_URL .env | cut -d= -f2)/api/v1/edge/info"

# B) Named Tunnel:
curl -sS https://edge-r1.tunnel.example.com/api/v1/edge/info
```

**2) Cloud süperadmin panelinde:**
Restoran kartı **ONLINE** + son hello dakikalar içinde + Edge URL doğru.

**3) Personel LAN içinden:**
`http://<edge-makinesi-ip>/` → edge_frontend login (Caddy plain HTTP port 80).

**4) Misafir QR (uçtan uca):**

- Cloud admin'den QR PDF üret (URL `https://<CLOUD_HOSTNAME>/r/...` olmalı).
- Telefon QR oku → Cloud `/r/...` → Flutter `https://<CLOUD_HOSTNAME>/#/guest/qr?...&via=cloud`.
- Menü REST'i Cloud BFF üzerinden Edge'e proxy yapılır (`PUBLIC_EDGE_URL`'e).
- WS bağlantısı `edgeRealtimeBaseUrl` → Edge tunnel URL'sine.

---

## 4. Yaygın sorunlar

| Belirti | Olası neden | Çözüm |
|---------|-------------|--------|
| Cloud süperadmin: Edge **OFFLINE** | Hello gitmiyor | Edge log → `cloud.base-url` doğru mu, çıkış 443 açık mı |
| Misafir: *Edge unreachable* | `public-edge-url` LAN IP / tunnel kapalı | `.env` doğru hostname + cloudflared sağlıklı |
| Misafir WS bağlanmıyor | Tunnel WebSocket desteklemiyor (nadiren) | Cloudflare dashboard → tunnel → WS otomatik |
| Tarayıcı `cloud.example.com` → 502 | Cloud container ayakta değil | `docker compose ps`, log |
| `cloud_frontend` 404 / boş | `build/web` bind mount eksik | `ls cloud_frontend/build/web` ve compose restart |
| Resim yükleme 413 | İstemci 5 MB üstünde resim | `QUICKSERVE_MEDIA_MAX_IMAGE_BYTES` ↑ |
| Edge restart loop | Flyway hata | `docker compose logs edge` |

---

## 5. Güvenlik kontrol listesi (test deploy sonrası)

- [ ] `application-prod.yml` `JWT_SECRET` env'den geliyor — repo'da yok.
- [ ] PostgreSQL parolaları en az 16 karakter.
- [ ] Cloud süperadmin parolası demo'dan değiştirildi.
- [ ] Restoran admin parolası değiştirildi.
- [ ] `quickserve.guest-lab-enabled=false` (prod).
- [ ] `/api/v1/sync/**` şu an `permitAll` — kısa vadede Edge ↔ Cloud API key planla.
- [ ] Edge makinesi disk şifrelemesi (yerel veriler).
- [ ] Compose servisleri için log rotasyonu (`docker compose logs --tail`).

---

## 6. Sonraki adımlar

1. **Senkron auth:** `/api/v1/sync/**` için Edge API key veya mTLS.
2. **CI/CD:** Build → push image → VPS'te `docker compose pull && up -d`.
3. **Backup:** Cloud Postgres günlük dump (`pg_dump` cron + S3).
4. **Monitoring:** Cloud uptime, cloudflared bağlantı sayısı, Edge hello eşiği uyarı.
5. **Cloud WS proxy:** Misafir WS'i de Cloud üzerinden taşı (planda).
