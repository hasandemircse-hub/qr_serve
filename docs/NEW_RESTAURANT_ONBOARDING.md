# QuickServe — Yeni Restoran Kurulum Playbook'u

**Son güncelleme:** 2026-05-26
**Kapsam:** Yeni bir restoran müşteriye QuickServe sisteminin sıfırdan kurulumu — donanım seçimi, ofis hazırlık, saha kurulumu, eğitim, ve kurulum sonrası süreçler.

İlgili belgeler:
- [QUICKSERVE_PLAN.md](./QUICKSERVE_PLAN.md) — Ürün ve mimari planı
- [DEPLOY_TEST.md](./DEPLOY_TEST.md) — İlk Cloud/Edge deploy
- [CLOUD_EDGE_INTERNET.md](./CLOUD_EDGE_INTERNET.md) — Network/tunnel mimarisi

---

## 📦 FAZ 0 — Donanım Seçimi ve Tedarik (1-3 gün önce)

### Edge cihazı için kriterler

| Kriter | Minimum | Önerilen | Premium |
|---|---|---|---|
| **Form factor** | Raspberry Pi 5 (8GB) | **Intel NUC / Mini PC** | Industrial fanless mini PC |
| **CPU** | ARM Cortex-A76 (Pi 5) | Intel N100 / N200 | Intel i3-N305 / i5 |
| **RAM** | 8 GB | **16 GB** | 32 GB |
| **Storage** | 64 GB SD card | **256 GB NVMe SSD** | 512 GB NVMe SSD + 1TB HDD backup |
| **Network** | WiFi only | **Gigabit Ethernet + WiFi** | 2x Ethernet (failover) |
| **Power** | USB-C 5V | 12-19V DC | Geniş aralık (12-24V) |
| **UPS uyumlu** | Hayır | Evet (5V Pi UPS HAT) | Evet (online UPS) |
| **Fiyat (TR, 2026)** | 4.000-6.000 TL | **8.000-15.000 TL** | 20.000-35.000 TL |

### Pratik tavsiye — **Intel NUC / mini PC** (önerilen)

Pi 5 cazip ama saha gerçekleri:
- Docker imajları AMD64 → Pi'de ARM image build etmen gerek
- Restoran ortamı: yağ buharı, sıcaklık, tozdan **fanlı sistem zorlanır** → fanless mini PC daha iyi
- SD card 1-2 yılda bozulur → NVMe SSD 5+ yıl
- 16 GB RAM = uzun vadede sorun yok (PostgreSQL + JVM + Caddy + Cloudflared)

**Türkiye'de bulabileceğin modeller (2026 yaklaşık)**:
- Beelink Mini S12 Pro (N100, 16GB, 500GB SSD) ~9.500 TL
- ASUS NUC 13 Mute (i3-N305) ~14.000 TL
- MeLE Quieter4C (fanless!) ~11.000 TL — **mutfak/yağ ortamı için ideal**

### Periferi (her restoran için liste)

| Donanım | Adet | Tahmini fiyat | Not |
|---|---|---|---|
| Edge mini PC | 1 | 10.000 TL | Yukarıdan |
| **UPS (kesintisiz güç)** | 1 | 1.500-3.000 TL | APC Back-UPS 650VA — elektrik kesintisi şart |
| USB ethernet adapter (yedek) | 1 | 200 TL | NUC tek ethernet'liyse |
| HDMI kablo + küçük monitor | 1 set | 1.500 TL | İlk kurulum/hata teşhis için |
| USB klavye/mouse | 1 set | 500 TL | Aynı amaçla |
| WiFi router (yoksa) | 1 | 1.500-3.000 TL | TP-Link Archer C6 mesh + 2.4/5GHz |
| **Termal yazıcı** (mutfak/kasa) | 1-3 | 2.000-4.000 TL/adet | Network printer, Epson TM-T20 |
| Tablet (kasa için) | 1-2 | 5.000-15.000 TL | iPad / Samsung Tab A — opsiyonel |
| **QR kod baskı (kuşe + lamine)** | masa sayısı | 50-150 TL/adet | Yerel matbaa |
| Personel telefonları | restorana ait | — | Garson kendi telefonu, BYOD |

**Toplam restoran başına maliyet: ~20.000 - 40.000 TL** (Edge + UPS + yazıcı + QR'lar dahil)

---

## 🏗 FAZ 1 — Ofiste Hazırlık (kurulumdan 1-2 gün önce)

### 1.1 Cloud'da restoran kaydı oluştur

Süperadmin paneline (`https://qrserve.co`) gir:

```
1. Süperadmin login (admin@qrserve.co / 1)
2. "Restoranlar" → "Yeni Restoran"
3. Doldur:
   - İsim: "Lezzet Durağı"
   - Şehir / Vergi No / Adres
   - Subscription: Active
4. Kaydet
5. Oluşan UUID'yi kopyala → bu QUICKSERVE_RESTAURANT_ID
```

### 1.2 Restoran admin kullanıcısı oluştur

Aynı panelden:

```
1. Restoran detayında "Kullanıcılar" → "Yeni"
2. Email: admin@lezzet-duragi.com
3. Şifre: geçici güçlü şifre (kurulumda değiştirilecek)
4. Rol: RESTAURANT_ADMIN
```

### 1.3 Cloudflare Named Tunnel oluştur

Cloudflare Zero Trust → Networks → Tunnels:

```
1. "Create a tunnel" → Cloudflared seç
2. İsim: quickserve-edge-r-lezzet
3. "Docker" sekmesinde token kopyala (eyJh...)
4. "Public Hostname" sekmesinde ekle:
   - Subdomain: edge-lezzet
   - Domain: qrserve.co
   - Service: HTTP, URL: edge:8081
5. DNS kontrol: edge-lezzet.qrserve.co CNAME otomatik oluştu mu?
```

### 1.4 Bilgisayar üzerinde Edge image'ı hazırla

Ofiste, restorana götürmeden önce **tüm imaj kurulumunu yap**, böylece sahada sadece "aç-tak" yaparsın.

**Adım 1: İşletim sistemi**
```bash
# Ubuntu Server 24.04 LTS — minimal kurulum
# (mini PC ile geliyorsa Windows'u silip Ubuntu yükle)
# - SSH enable
# - User: quickserve (sudo yetkili)
# - Hostname: edge-lezzet
# - Disk: tüm disk LVM + LUKS encryption (yerel veri güvenliği)
```

**Adım 2: Docker + Compose**
```bash
ssh quickserve@edge-lezzet.local
sudo apt update && sudo apt install -y docker.io docker-compose-plugin git make
sudo usermod -aG docker quickserve
# logout/login
```

**Adım 3: Self-contained Edge bundle (sen build sunucusunda hazırlamış olmalısın)**

Senin ofisinde, restorana gitmeden önce **bir kez** build:

```bash
# Build sunucusunda (Mac/Linux)
cd ~/Desktop/projects/quickserve
./deploy/scripts/build-edge-images.sh --tag v0.1.0 --platform linux/amd64
# → /tmp/quickserve-edge-bundle-v0.1.0.tar.gz (≈190 MB, içinde imaj + compose + install.sh)
```

Edge cihazına bu **tek dosyayı** taşı (USB / scp), ve aç:

```bash
# Edge cihazında (kod tabanı / git clone GEREKMEZ)
mkdir -p ~/quickserve-install && cd ~/quickserve-install
# tar.gz'i buraya kopyala (USB veya scp ile)

sha256sum -c quickserve-edge-bundle-v0.1.0.tar.gz.sha256   # doğrulama
tar -xzf quickserve-edge-bundle-v0.1.0.tar.gz
cd quickserve-edge-bundle-v0.1.0

# install.sh: docker load + /opt/quickserve/deploy/edge oluştur + .env hazırla
sudo bash install.sh
```

> **Neden bundle?** Restoran cihazının interneti zayıf olabilir, sahada `git clone` + Docker build (Maven + Flutter SDK pull, ≈3 GB) yapacak vakit/bant genişliği yok. Senin tarafta `build-edge-images.sh` self-contained tar.gz çıkarır, cihazda sadece tek komutluk install (≈30 sn).

**Adım 4: `.env` doldur** (bu restoran için)

`install.sh` zaten `.env`'i `.env.example`'dan oluşturup `EDGE_TAG`'i otomatik set etti. Şimdi placeholder değerleri gerçeklerle değiştir:

```bash
sudo nano /opt/quickserve/deploy/edge/.env
```

Doldurulacak alanlar:

```env
# Restoran kimliği
QUICKSERVE_EDGE_ID=$(uuidgen)
QUICKSERVE_RESTAURANT_ID=<faz 1.1'de oluşturulan UUID>

# Cloud bağlantısı
QUICKSERVE_CLOUD_BASE_URL=https://qrserve.co
QUICKSERVE_PUBLIC_CLOUD_URL=https://qrserve.co

# Public Edge URL (Named Tunnel)
QUICKSERVE_PUBLIC_EDGE_URL=https://edge-lezzet.qrserve.co
CLOUDFLARED_TUNNEL_TOKEN=eyJh...faz 1.3'ten...

# LAN — restoran içi DNS adı
EDGE_LAN_HOSTNAME=edge.local

# Güvenlik — her restoran için ayrı
POSTGRES_PASSWORD=$(openssl rand -base64 32)
QUICKSERVE_JWT_SECRET=$(openssl rand -base64 48)

# Misafir lab kapalı (üretim)
QUICKSERVE_GUEST_LAB_ENABLED=false
```

> ⚠️ **`.env` dosyasını parola kasanda sakla** (Bitwarden / 1Password). Restoran adı altında entry oluştur, JWT secret + DB password + Cloudflared token + Restaurant UUID hepsini içine koy. **Bu olmazsa felaket kurtarma yapamazsın.**

**Adım 5: İlk başlatma (ofisteyken test et)**

```bash
# Edge cihazında — `--build` YOK, imajlar zaten Adım 3'te yüklendi
cd ~/quickserve-install/quickserve-edge-bundle-v0.1.0
sudo bash install.sh --start

# Veya manuel:
cd /opt/quickserve/deploy/edge && docker compose up -d
docker compose logs -f edge cloudflared
```

İlk açılış: postgres init ~10 sn, edge Spring Boot ~30 sn, cloudflared register ~5 sn. Toplam ~1 dk içinde hazır.

Beklenen log satırları:
- `Started EdgeApplication`
- `EdgeDiscoveryService` Cloud'a hello attı
- `cloudflared` Connection registered
- Cloud panelinden bak: restoran **ONLINE**

**Adım 6: Smoke test ofiste**

```bash
# Public Edge URL erişilebilir mi?
curl -sS https://edge-lezzet.qrserve.co/api/v1/edge/info
# Beklenen: {"edgeId":"...","restaurantId":"..."}

# Cloud üzerinden proxy çalışıyor mu?
# Tarayıcıdan: https://qrserve.co/admin/restaurants
# Lezzet Durağı → ONLINE, Edge URL doğru
```

**Adım 7: Cihazı kapat, kurulum çantasına koy**

```bash
sudo shutdown -h now
```

✅ Cihaz artık plug-and-play. Restoranda sadece elektrik + ethernet takarsan açılır.

---

## 🚚 FAZ 2 — Restoranda Kurulum (kurulum günü)

### 2.1 Saha keşfi (ideal: 1 gün önce)

| Kontrol | Soru | Aksiyon |
|---|---|---|
| **İnternet** | Fiber var mı? Hız? | Speedtest, minimum 20/5 Mbps stabil |
| **WiFi kapsama** | Mutfak + en uzak masa sinyal? | Gerekirse mesh router |
| **Edge yerleşim** | Klimalı/serin, yağa uzak, hırsız erişimi kısıtlı? | Kasa arkası / yönetici odası |
| **Priz** | Edge + UPS + yazıcılar için | Aynı hat, UPS önerilir |
| **Masa sayısı** | Final QR kod sayısı | Cloud'da seed et |
| **Yazıcı yerleri** | Mutfak (sıcak), kasa (soğuk) | Network kablo / WiFi |

### 2.2 Fiziksel kurulum (1-2 saat)

```
1. Edge cihazı → kasa arkasındaki rafta, havalandırılan yer
2. UPS prize → Edge ve router UPS'ten beslensin
3. Ethernet → router'a
4. Yazıcıları LAN'a bağla (ethernet veya WiFi)
5. Cihazı aç → otomatik docker compose up (systemd ile zaten ayarlı)
```

### 2.3 Network ayarları

Router'da:
```
1. Edge cihazına SABİT IP rezerve et (DHCP reservation, MAC adresinden)
   Örn: 192.168.1.100
2. DNS adı için:
   - Basit: hosts dosyası (her cihazda 192.168.1.100 edge.local)
   - Pro: router'da local DNS varsa edge.local → 192.168.1.100
3. Yazıcı IP'leri de sabit
4. WiFi:
   - Personel: kapalı SSID, WPA3, ana router
   - Misafir: ayrı misafir SSID (isteğe bağlı)
```

### 2.4 Cihaz açılış doğrulaması

```bash
# Yerel ağdan SSH ile gir
ssh quickserve@192.168.1.100
docker compose -f /opt/quickserve/deploy/edge/docker-compose.yml ps
# 4 servis: postgres, edge, caddy, cloudflared → hepsi "Up"

# Cloud bağlantısı
curl -sS https://qrserve.co/api/v1/admin/restaurants/<rId>/edges
# ONLINE görmeli
```

---

## 🍽 FAZ 3 — Restoranı Kurulumla (kurulum günü)

### 3.1 Admin login + ilk konfigürasyon

Restoran admin'i kasa tabletinden veya laptop'tan:

```
1. http://edge.local/  → restoran admin login
2. admin@lezzet-duragi.com / geçici şifre → şifre değiştir
3. "Ayarlar" → restoran bilgileri (saatler, KDV, para birimi)
```

### 3.2 Masa tanımları

```
1. "Masa Yönetimi" → "Yeni Masa"
2. Her masa için label: "Bahçe-1", "İç-5", "Teras-A2"
3. Toplam masa sayısı (örn. 25 masa)
```

### 3.3 Menü girişi (en uzun adım, 2-4 saat)

İki yol:

**A) Excel/CSV ile toplu** (menü uzunsa öneririm):
- Cloud admin'de menü import sayfasından CSV yükle
- Format: kategori, ürün adı, açıklama, fiyat, KDV, opsiyon grubu
- Excel template'i ver, restoran sahibi doldurur

**B) Tek tek manuel**:
- Kategori oluştur (Çorbalar, Ana Yemekler, İçecekler, Tatlılar)
- Her ürünü ekle: foto + açıklama + fiyat
- Opsiyon grupları: "Pişirme derecesi", "İçecek boyutu", "Ekstra"

> 💡 İlk müşterilerde menü girişini sen yap, sonra restoran sahibine eğit. 1 saatlik eğitim yeter.

### 3.4 Personel kullanıcıları oluştur

```
1. "Kullanıcılar" → her personel için ayrı hesap
2. Rol seç: WAITER / CASHIER / KITCHEN / MANAGER
3. Basit şifre (personel kendisi değiştirir)
4. Personel telefonuna http://edge.local/ kaydı + iconla home screen'e ekle
```

### 3.5 Yazıcı eşleştirme (mutfak/kasa)

```
1. "Yazıcı Ayarları" → "Yeni Yazıcı"
2. Tip: KITCHEN / RECEIPT / BAR
3. IP: 192.168.1.50, Port: 9100, Protocol: ESC/POS
4. Test print
5. Kategorileri yazıcıya ata (Çorbalar+Ana Yemekler → Mutfak, İçecekler → Bar)
```

### 3.6 QR kodları üret ve bas

```
1. Cloud admin → "QR PDF"
2. Restoran seç → "Tümünü Üret"
3. PDF indir (her sayfada 6-8 masa QR'ı)
4. Yerel matbaada bas (kuşe + lamine), masa sayısı kadar
5. Masalara yapıştır (saydam masa stand'ı veya masaya direkt)
```

### 3.7 Smoke test (canlı)

| Adım | Beklenen |
|---|---|
| Telefondan QR oku | Menü açılır, restoran adı doğru |
| Sepete ekle, sipariş | Garson tabletinde bildirim |
| Garson çağır | Tabletinde alarm + masa numarası |
| Hesap iste | Aynı şekilde |
| Kasa tabletinden ödeme aç | Edge'de ödeme akışı |
| Mutfak yazıcı | Sipariş bastı mı? |
| Cloud panel | Sipariş Cloud'a sync oldu mu? (2-5 saniye gecikme normal) |

---

## 🎓 FAZ 4 — Eğitim ve Teslim (kurulum günü sonu)

### 4.1 Restoran sahibi/yönetici eğitimi (30 dakika)

| Konu | Süre |
|---|---|
| Admin panelinden menü değişikliği | 10 dk |
| Personel ekleme/şifre sıfırlama | 5 dk |
| Günlük rapor görüntüleme | 5 dk |
| QR yeniden basma | 5 dk |
| Acil durumda neyi nasıl yapar (cihaz kapanırsa restart) | 5 dk |

### 4.2 Personel eğitimi (her rol için 15 dk)

- Garson: bildirimleri açma, masa görüntüleme, sipariş gönderme
- Kasiyer: hesap kapatma, indirim uygulama, ödeme alma
- Mutfak: sipariş ekranı, hazır işaretleme

### 4.3 Teslim dokümanı

Restoran sahibine ver:
- **Kurulum sertifikası** (cihaz seri no, kurulum tarihi, garanti)
- **Login bilgileri** (geçici şifrelerin değiştirildiğine dair tutanak)
- **Acil destek hattı** (senin WhatsApp / telefon)
- **Kısa kullanım rehberi** (A4, laminat) — kasa yanına asılır

---

## 🔧 FAZ 5 — Kurulum Sonrası (sürekli)

### 5.1 İzleme — her gün otomatik

```
- UptimeRobot: edge-lezzet.qrserve.co → 5 dk'da ping
- Cloud süperadmin paneli: "ONLINE" mi?
- Disk doluluk uyarısı (>80% → e-posta)
- Backup başarılı mı? (gece 03:00 Postgres dump)
```

### 5.2 Backup stratejisi (kurulumda systemd timer ile aç)

```bash
# Cihazda /etc/systemd/system/quickserve-backup.timer
# Gece 03:00 Postgres dump → /opt/quickserve/backups/
# Hafta 1 kez Cloud S3 / Backblaze B2'ye upload (rclone)
```

### 5.3 Güncelleme stratejisi

```
- Cloud frontend / backend: senin tarafta deploy, restoran fark etmez
- Edge: ayda 1 kez, sahaya gitmeden:
  ssh + git pull + docker compose up -d --build
- Major version: önce 1 pilot restoranda test, sonra fleet
```

### 5.4 Felaket kurtarma senaryoları

| Senaryo | Çözüm | Süre |
|---|---|---|
| Cihaz arızası | Yedek cihaza son backup restore | 30 dk |
| SSD bozulması | UPS varsa veri kaybı yok, yenisi tak + restore | 1 saat |
| İnternet kesintisi | Personel akışı çalışır (offline-first) | — |
| Cloud kesintisi | Personel etkilenmez, müşteri QR durur | — |
| Cloudflare tunnel down | Müşteri QR durur, personel çalışır | Cloudflare uptime'a bağlı |
| Cihaz çalınma/kaybı | Yedek cihaz + restore, JWT secret rotate | 2 saat |

---

## 📋 Kurulum Çantası (her sahaya götür)

```
☐ Hazırlanmış Edge cihazı (image yüklü, test edilmiş)
☐ UPS + güç kablosu
☐ Ethernet kablosu (3m + 10m)
☐ HDMI kablo + portable monitor
☐ USB klavye/mouse
☐ Etiket yazıcı (cihaz üstüne seri no, IP, hostname etiketi yapıştır)
☐ Yazıcı/cihaz IP atama listesi (önceden plan)
☐ Multimetre (kötü priz kontrol)
☐ Wi-Fi şifresi (gerekirse router resetle)
☐ Laptop (yedek SSH + admin panel için)
☐ QR PDF'leri matbaada hazır basılmış olsun
☐ Restoran teslim dokümanı + tutanak çıktısı
☐ Yedek SD card / USB (cihaz tamir gerekirse)
☐ "Quickserve garanti / destek" iletişim kartı
```

---

## ⏱ Zaman tahmini

| Faz | Süre |
|---|---|
| Donanım sipariş + bekleme | 2-7 gün |
| FAZ 1 (ofis hazırlık) | 2-3 saat |
| FAZ 2 (restoran fiziksel) | 1-2 saat |
| FAZ 3 (menü + masa + QR) | **3-5 saat** (menü girişi en uzun) |
| FAZ 4 (eğitim) | 1 saat |
| **Toplam (donanım hariç)** | **~8 saat / 1 iş günü** |

İyi planlandığında **tek günde restoran canlıya alınır**.

---

## 🚀 Ölçeklenebilirlik — 10+ restoran olunca

Şu an manuel akış. Restoran sayısı arttıkça yapacakların:

1. **Imaj otomasyonu**: cihaz USB'den boot edip self-provision olsun (cloud-init + ansible)
2. **`provision-edge.sh` script**: tek komutla `.env` oluştur + frontend rsync + compose up
3. **Cloud süperadmin "Restoran Wizard"**: restoran kaydı, Cloudflare tunnel oluşturma, token aktarma API'leri ile otomatik
4. **Remote management**: Tailscale / WireGuard ile tüm Edge'lere VPN üzerinden SSH (saha gitmeden destek)
5. **Filo izleme**: Grafana dashboard, tüm Edge'lerin sağlığı tek ekranda
6. **OTA Edge update**: cloud'dan tetiklenen güncelleme akışı

Bunlar şimdi gerekmiyor — ilk 5 restoran için manuel akış yeterli. 10. restoranda yatırım yap.

---

## 📚 Referanslar

- Cloud deploy: [DEPLOY_TEST.md §2](./DEPLOY_TEST.md#2-cloud-sunucu-kurulumu)
- Cloudflare Named Tunnel detayı: [deploy/edge/cloudflared/README.md](../deploy/edge/cloudflared/README.md)
- Edge `.env.example`: [deploy/edge/.env.example](../deploy/edge/.env.example)
- Network ve tunnel mimarisi: [CLOUD_EDGE_INTERNET.md](./CLOUD_EDGE_INTERNET.md)
