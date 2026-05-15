# QuickServe — Canlı Ürün ve Teknik Plan

**Son güncelleme:** 2026-05-13  
**Amaç:** Ürün vizyonu, mimari hedefler ve *gerçek kod tabanı durumu* tek yerde; her anlamlı iş sonrası güncellenir. Cursor / AI ve ekip bu dosyayı referans alır.

---

## Bu dosyayı nasıl güncellersiniz?

1. **Yapılan işi** aşağıdaki ilgili tabloda `Yapıldı` / `Kısmen` / `Yapılmadı` sütununa ve **Not** alanına işleyin.  
2. **§ 9 Güncelleme günlüğü**ne kısa bir madde ekleyin: tarih, ne değişti, hangi modül (edge / cloud / common / edge_frontend / cloud_frontend).  
3. Büyük mimari sapma olursa **§ 1–6** metinlerini hedefle uyumlu olacak şekilde düzeltin (sadece gerektiğinde).  
4. AI asistanından istek: *“QUICKSERVE_PLAN.md’yi şu işe göre güncelle”* — diff bu dosyada kalmalı.

---

## 1. Teknik mimari ve veri omurgası (The Backbone)

| İlke | Hedef (ürün metni) | Kod / durum özeti |
|------|-------------------|-------------------|
| **Cloud–Edge hibrit** | Merkez Cloud + restoran başına Edge (RPi vb.) | `cloud` ve `edge` Spring Boot modülleri; `common` ortak domain/sync. **Misafir internet trafiği:** şu an demo/lab’da doğrudan Edge; **hedef** QR ve misafir oturumunun Cloud üzerinden yönetilip siparişin ilgili Edge’e yönlendirilmesi (public guest BFF — kodda henüz yok). |
| **Offline-first** | İnternet kesilince yerel işlem devam | Edge DB + senkron outbox deseni; tam “kesinti simülasyonu” test senaryosu dokümante değil. |
| **Akıllı senkron** | UUID, LWW, initial sync, anlık push | UUID + `SyncEntityMergeService` (LWW) Cloud/Edge’te; `POST …/sync/edge/hello`, `GET …/sync/bootstrap`, Edge `EdgeDiscoveryService`. |
| **Real-time (LAN)** | Garson / mutfak / kasa anlık | `WebSocket` / kat planı kısmen; mutfak push (`/ws/v1/kitchen/push`) + `kitchen_landing` yenileme **kısmen**; kasa/garson tam WS **yapılmadı**. |

---

## 2. Aktörler ve yetki alanları

### A. Superadmin (bulut)

| Özellik | Durum | Not |
|---------|--------|-----|
| Restoran CRUD, dondurma, demo | **Kısmen** | Cloud API: liste + `PATCH …/subscription`. **POST yeni restoran / silme** yok. |
| Canlı izleme (online/offline, last seen) | **Yapılmadı** | `edge_sync_checkpoint` alanları DB’de; **yönetim UI + raporlama API** yok. |
| Impersonation | **Yapılmadı** | — |

**İstemci:** `cloud_frontend` — giriş + restoran listesi/abonelik. **Edge içinde süperadmin yok** (bilinçli ayrım).

### B. Restoran admini (Edge)

| Özellik | Durum | Not |
|---------|--------|-----|
| Mekan tasarımı (kat, sürükle-bırak, birleştir/böl) | **Kısmen** | `floor_design_editor_screen`, `FloorLayoutRestController`, birleştirme/bölme API’leri. |
| Gelişmiş menü (ürün/grup, sıra, resim, notlar) | **Kısmen** | Menü/ürün entity + QR ürün sihirbazı; tam CRUD ve resim yükleme **eksik**. |
| Seçenekli ürünler | **Kısmen** | `product_option_wizard_screen` + backend sihirbazı. |
| Personel yönetimi | **Yapılmadı** | RBAC seed var; **admin UI yok**. |
| QR masa yönetimi | **Kısmen** | PDF/URL üretimi tarafı; tam “geçersiz kıl” yaşam döngüsü UI **kısmen**. |

**İstemci:** `edge_frontend` — `/admin`, kurulum sihirbazı `/admin/setup` (Edge `setup` API).

### C. Saha personeli (Edge)

| Rol | Durum | Not |
|-----|--------|-----|
| Garson | **Kısmen** | `GET /api/v1/waiter/tables|menu`, `POST /api/v1/waiter/orders` + `edge_frontend` masa→menü→sepet. **Seçenekli ürün** garson UI’da yok (sadece `steps: []` uyumlu ürünler). |
| Mutfak | **Kısmen** | `GET /api/v1/kitchen/queue`, `POST …/received|ready` + JWT restoran doğrulaması; `kitchen_landing` + mutfak WS yenileme; `LINE_KITCHEN_STATUS` push. Garson ekranında hazır bildirimi **yok**. |
| Kasiyer | **Kısmen** | `GET /api/v1/cashier/open-orders`, `cashier_landing` + `BillingController` (`REMAINDER` + bahşiş, Nakit/Kart). Kısmi ödeme / iade UI **yok**. |

### D. Müşteri (QR)

| Özellik | Durum | Not |
|---------|--------|-----|
| Uygulamasız menü / sepet / garson çağır | **Kısmen** | Edge `GuestMenuRestController` + token yolu. **Flutter:** `edge_frontend` rotaları `/guest-lab` (test: tüm masalar + token) ve `/guest/qr?r=&t=&k=` (QR okuma simülasyonu). Statik Edge `/guest` SPA hâlâ yedek olarak duruyor; birincil test arayüzü Flutter. |
| Sipariş durumu anlık izleme | **Kısmen** | `GET …/orders/open` + `ORDER_CONFIRMED` / `LINE_KITCHEN_STATUS` WS; Flutter `GuestQrMenuScreen` ile Durum sekmesi. |
| Seçenekli ürün (misafir) | **Kısmen** | `GET …/products/{id}/option-wizard` (token doğrulamalı). |
| Misafir lab (dev) | **Yapıldı** | `quickserve.guest-lab-enabled=true` iken `GET /api/v1/guest/lab/restaurants/{id}/tables` — masa listesi + geçerli `TableGuestToken`. **Varsayılan kapalı;** `application-local.yml` içinde açık. |
| Cloud üzerinden misafir (internet QR) | **Yapılmadı** | Hedef mimari: public guest endpoint Cloud’da; restoran/Edge eşlemesi ve güvenli yönlendirme — implementasyon bekleniyor. |

**Hedef iş akışı (ürün):** Müşteri QR’ı internet üzerinden **Cloud**’a gider; Cloud hangi restoran/Edge olduğunu çözer ve sipariş/durum trafiğini doğru Edge örneğine bağlar (offline dönemlerde Edge LAN davranışı aynı kalır).

**Şu anki yerel test akışı:** Edge `local` + lab açık → Flutter Web `/#/guest-lab?restaurantId=<uuid>` → masaya tıkla → `/guest/qr?r=&t=&k=` ile Edge guest API + WS (Cloud katmanı olmadan).

---

## 3. Operasyonel iş akışları (The Journey)

### Misafir (QR) — hedef vs mevcut

| Aşama | Hedef (Cloud-first) | Mevcut kod / test |
|-------|---------------------|-------------------|
| QR / link | Cloud public URL; restoran ve masa Cloud’da çözülür | Yerelde: Flutter **Misafir lab** veya doğrudan Edge `/guest` URL’si |
| Oturum | Cloud veya Edge BFF; token güvenli dağıtım | Edge `TableGuestToken` + `GET …/guest/.../session` |
| Menü / sepet | Cloud proxy → Edge veya sync cache (tasarım kararı) | Edge `GET …/menu`, sepet istemci tarafı |
| Sipariş | Cloud → doğru Edge `POST …/orders` | Edge’e doğrudan `POST …/orders` |
| Durum | WS/REST Edge veya Cloud agregasyonu | Edge `ws://…/ws/v1/guest?…` + REST `orders/open` |

| Adım | Durum | Not |
|------|--------|-----|
| QR → oturum / masa | **Kısmen** | Token + session API; Flutter lab ile toplu masa testi. |
| Sepet → onay → mutfak | **Kısmen** | Edge’de sipariş + mutfak WS + `kitchen_landing` gerçek kuyruk. Tam otomasyon (sipariş kapanışı, mutfak dışı roller) **kısmen**. |
| Alındı / hazır bildirimleri | **Kısmen** | Mutfak UI + Edge API + mutfak WS (`LINE_KITCHEN_STATUS`); misafir token’lı siparişte konuk WS. **Garson** anlık bildirim yok. |
| Ödeme (ürün/tutar/toplam, bahşiş) | **Kısmen** | `BillingPaymentService` + kasa UI: kalan tahsilat + bahşiş. Parçalı satır ödemesi / fatura entegrasyonu **kısmen**. |
| Masa kapanışı | **Yapılmadı** | — |

---

## 4. Entegrasyonlar ve yasal uyumluluk

| Konu | Durum | Not |
|------|--------|-----|
| ESC/POS yazıcı | **Kısmen** | `print` yapılandırması + `PrintTestController`; personelde tam yazıcı yönetim UI **yok**. |
| E-fatura / e-adisyon | **Kısmen** | Genişletilebilir alan için migration/entity yönü; **entegrasyon yok**. |
| POS donanım | **Yapılmadı** | — |

---

## 5. Geliştirici deneyimi (DX) ve kurulum

| Özellik | Durum | Not |
|---------|--------|-----|
| Smart setup / Edge–Cloud eşleşme | **Kısmen** | `EdgeSetupController`, `EdgeDiscoveryService`, `MODE` / `only-edge` profili, `config/quickserve-config.sample.yaml`. |
| Simülasyon: Edge-only | **Yapıldı** | `only-edge` + mock Cloud. |
| Full-stack local | **Yapıldı** | Cloud + Edge `local` + H2 + `migration-local`. |
| Misafir lab testi (Flutter Web) | **Yapıldı** | Edge `local` + `guest-lab-enabled: true` (`application-local.yml`). Flutter Web’de `HashUrlStrategy` (`main.dart`): `/#/guest-lab?…` ve `#/guest/qr?…` adresleri path stratejisi yüzünden boş sayfa vermez. Örnek: `http://127.0.0.1:<web-port>/#/guest-lab?restaurantId=11111111-1111-1111-1111-111111111111` — masaya tıklayınca QR simülasyonu. `edgeBaseUrl` web’de `resolveEdgeBaseUrl` ile `127.0.0.1:8081` hizalanmalı. |
| Cloud-only (sadece panel) | **Kısmen** | `cloud_frontend` var; Cloud **PostgreSQL** modunda ayrı çalıştırma dokümante değil. |

**Launch:** `.vscode/launch.json` — Java Cloud/Edge, Flutter `edge_frontend` / `cloud_frontend`.

---

## 6. Global vizyon

| Özellik | Durum |
|---------|--------|
| i18n | **Yapılmadı** (metinler çoğunlukla TR). |
| Çoklu para birimi / vergi profili | **Kısmen** (sabit/demo vergi alanları); konfigürasyon katmanı **sınırlı**. |

---

## 7. Repo envanteri (kısa)

| Parça | İçerik |
|-------|--------|
| `common` | Entity, Flyway `migration` + `migration-local`, `SyncEntityMergeService`, auth ortakları. |
| `cloud` | Auth, sync, `AdminRestaurantController`, güvenlik + CORS. |
| `edge` | Auth (süperadmin yok), guest (REST + `/guest` SPA + `manifest.json` + **misafir lab**), layout, QR, kitchen, billing, print, setup, sync, güvenlik + CORS. |
| `edge_frontend` | Personel: login, admin (kat/QR), garson/mutfak/kasa Edge API ile **kısmen** bağlı; setup sihirbazı. **Misafir:** `/guest-lab`, `/guest/qr` (giriş gerektirmez). |
| `cloud_frontend` | Süperadmin: login + restoran listesi/abonelik. |
| `config/` | Örnek `quickserve-config.sample.yaml`. |

---

## 8. Öncelik önerisi (sıradaki işler — taslak)

1. ~~Garson: masa → menü → sepet → Edge sipariş API.~~ *(Edge API + `waiter_landing` temel akış tamam; seçenekli ürün / harita sonraki.)*  
2. ~~Mutfak: gerçek kuyruk + durum butonları + (isteğe bağlı) WS.~~ *(Temel kuyruk + butonlar + WS yenileme tamam; garson push / servis çıkışı API sonraki.)*  
3. ~~Kasa: açık adisyon + `BillingController` ile ödeme.~~ *(Açık liste API + `cashier_landing` kalan tahsilat; kısmi/iade sonraki.)*  
4. Misafir: Flutter `edge_frontend` `/guest-lab` + `/guest/qr` + Edge guest option-wizard; **Cloud public misafir BFF** ve internet QR yönlendirmesi sonraki sprint. Statik `/guest` yedek.  
5. Cloud: Edge listesi / last seen API + `cloud_frontend` ekranı.  
6. Cloud: restoran **oluşturma** (POST) süperadmin için.

*(Öncelik ürün kararına göre değiştirilir; değişince bu bölümü güncelleyin.)*

---

## 9. Güncelleme günlüğü

| Tarih | Özet | Modül |
|-------|------|--------|
| 2026-05-13 | Flutter Web: `HashUrlStrategy` + `/` → `/login` yönlendirmesi; `/#/guest-lab` boş sayfa (path/hash uyumsuzluğu) giderildi; `go_router` `errorBuilder`. | edge_frontend, docs |
| 2026-05-13 | Misafir: Edge **misafir lab** API (`guest-lab-enabled`) + Flutter `/guest-lab` (masa listesi) ve `/guest/qr` (token’lı menü/sepet/sipariş/WS + option-wizard); `go_router` misafir rotaları girişsiz; plan dokümanı Cloud-first misafir hedefi + yerel test linki. | edge, edge_frontend, docs |
| 2026-05-13 | Misafir: `GET …/guest/.../orders/open`, `GuestOrderStatusResponse`; `GuestMenuService` + repo sorgusu; `/guest` SPA Durum sekmesi (REST + WS birleşimi), `manifest.json`. | edge, common, docs |
| 2026-05-13 | Kasa: `GET /api/v1/cashier/open-orders`, `CashierOpenOrdersService` + `RestaurantOrderRepository` status filtresi; `cashier_landing` + `edge_cashier_api` (`BillingController` özet/ödeme). | edge, common, edge_frontend, docs |
| 2026-05-13 | Mutfak: `GET /api/v1/kitchen/queue`, `KitchenQueueService`; `KitchenStationController` tabanı `/api/v1/kitchen` (POST yolları aynı); satır işlemlerinde JWT `restaurantId` doğrulaması; `GuestOrderRealtimeBridge` mutfak WS `LINE_KITCHEN_STATUS`; `kitchen_landing` + `edge_kitchen_api` REST/WS; `RestaurantOrderRepository` OPEN sorgusu. | edge, common, edge_frontend, docs |
| 2026-05-13 | Garson: Edge `WaiterRestController` (`/api/v1/waiter/tables`, `/menu`, `/orders`); `QrOrderService` + `GuestOrderRealtimeBridge` masa siparişlerinde mutfak push; `CreateQrOrderRequest.channel`; `edge_frontend` garson ekranı API + sepet. | edge, edge_frontend, docs |
| 2026-05-13 | İlk sürüm: ürün metni + mevcut kod durumu + bakım kuralları; Flyway `V14` local seed (V11 çakışması giderildi); Cloud/Edge frontend ayrımı, planlanan eksikler işlendi. | docs |

<!-- Yeni satırlar tablonun ÜSTüne ekleyin (en yeni üstte). -->
