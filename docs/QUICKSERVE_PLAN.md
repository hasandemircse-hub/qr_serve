# QuickServe — Canlı Ürün ve Teknik Plan

**Son güncelleme:** 2026-05-19  
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
| **Cloud–Edge hibrit** | Merkez Cloud + restoran başına Edge (RPi vb.) | `cloud` ve `edge` Spring Boot modülleri; `common` ortak domain/sync. Misafir internet: Cloud BFF REST proxy + QR redirect (**kısmen**); Edge’e WS doğrudan. **Altyapı rehberi:** [CLOUD_EDGE_INTERNET.md](./CLOUD_EDGE_INTERNET.md). |
| **Offline-first** | İnternet kesilince yerel işlem devam | Edge DB + senkron outbox deseni; tam “kesinti simülasyonu” test senaryosu dokümante değil. |
| **Akıllı senkron** | UUID, LWW, initial sync, anlık push | UUID + `SyncEntityMergeService` (LWW) Cloud/Edge’te; `POST …/sync/edge/hello`, `GET …/sync/bootstrap`, Edge `EdgeDiscoveryService`. |
| **Real-time (LAN)** | Garson / mutfak / kasa anlık | Mutfak `/ws/v1/kitchen/push`; garson `/ws/v1/waiter/push` (hazır satır); kasa `/ws/v1/cashier/push` (yeni sipariş + liste yenileme). Kat planı canlılığı **kısmen**. |

---

## 2. Aktörler ve yetki alanları

### A. Superadmin (bulut)

| Özellik | Durum | Not |
|---------|--------|-----|
| Restoran CRUD, dondurma, demo | **Kısmen** | Cloud API: liste + `PATCH …/subscription` + `POST` oluşturma + soft-delete `DELETE`. |
| Canlı izleme (online/offline, last seen) | **Kısmen** | `GET /api/v1/admin/restaurants` → Edge durumu (`ONLINE` / `OFFLINE` / `NEVER_SEEN`, son hello, URL); `cloud_frontend` süperadmin kartları + 30 sn otomatik yenileme. Edge periyodik heartbeat (`EdgeHeartbeatScheduler`, ~60 sn). Eşik: `quickserve.admin.edge-online-threshold-seconds` (varsayılan 180). |
| Impersonation | **Yapılmadı** | — |

**İstemci:** `cloud_frontend` — giriş + restoran listesi/abonelik. **Edge içinde süperadmin yok** (bilinçli ayrım).

### B. Restoran admini (Edge)

| Özellik | Durum | Not |
|---------|--------|-----|
| Mekan tasarımı (kat, sürükle-bırak, birleştir/böl) | **Kısmen** | Kat planı editörü + salon WS (`/ws/v1/layout`); siparişte masa **OCCUPIED**. QR **yenile/iptal** (`guest-tokens`). |
| Gelişmiş menü (ürün/grup, sıra, resim, notlar) | **Kısmen** | Menü/ürün CRUD + **sürükle-bırak sıralama** + **ürün resmi** (JPEG/PNG/WebP, `V19`, `POST/DELETE …/image`, public `GET …/media/product-images/…`; admin yükle/kaldır; misafir/garson menüde küçük görsel). Notlar **eksik**. |
| Seçenekli ürünler | **Kısmen** | Misafir + garson: option-wizard API + paylaşılan seçim diyaloğu. Admin: grup/seçenek CRUD (`ProductOptionsAdminController`, `product_options_admin_screen`). |
| Personel yönetimi | **Yapıldı** | `StaffAdminController` (CRUD + şifre sıfırlama); `staff_admin_screen` Personel sekmesi; son admin / kendi hesap silme koruması. |
| QR masa yönetimi | **Kısmen** | PDF/URL + telefon QR; **rotate** / **revoke-all** token API + Kat planı **QR yenile / QR iptal**. |

**İstemci:** `edge_frontend` — `/admin`, kurulum sihirbazı `/admin/setup` (Edge `setup` API).

### C. Saha personeli (Edge)

| Rol | Durum | Not |
|-----|--------|-----|
| Garson | **Kısmen** | Masa→menü→sepet→sipariş; salon haritası; **masa devret**; hazır satır + **servis çıkışı** (`DELIVERED` API). |
| Mutfak | **Kısmen** | Kuyruk + received/ready + mutfak WS; `LINE_KITCHEN_STATUS` garsona da push. |
| Kasiyer | **Kısmen** | Açık adisyon + ödeme + kasa WS; masa kapat (standart / zorla / bakiye bırak). **Tümü / tutar / satır** tahsilat UI; iade Detay’dan. |

### D. Müşteri (QR)

| Özellik | Durum | Not |
|---------|--------|-----|
| Uygulamasız menü / sepet / garson çağır | **Kısmen** | Edge `GuestMenuRestController` + token yolu. **Flutter:** `edge_frontend` rotaları `/guest-lab` (test: tüm masalar + token) ve `/guest/qr?r=&t=&k=` (QR okuma simülasyonu). Statik Edge `/guest` SPA hâlâ yedek olarak duruyor; birincil test arayüzü Flutter. |
| Sipariş durumu anlık izleme | **Kısmen** | `GET …/orders/open` + `ORDER_CONFIRMED` / `LINE_KITCHEN_STATUS` WS; Flutter `GuestQrMenuScreen` ile Durum sekmesi. |
| Seçenekli ürün (misafir) | **Kısmen** | `GET …/products/{id}/option-wizard` (token doğrulamalı). |
| Misafir lab (dev) | **Yapıldı** | `quickserve.guest-lab-enabled=true` iken `GET /api/v1/guest/lab/restaurants/{id}/tables` — masa listesi + geçerli `TableGuestToken`. **Varsayılan kapalı;** `application-local.yml` içinde açık. |
| Cloud üzerinden misafir (internet QR) | **Kısmen** | Cloud BFF REST proxy + `GET /r/...` redirect (`via=cloud`). QR PDF ve lab’da **Cloud URL** (`public-cloud-url`). `guest.web-base-url` = Flutter Web (redirect). WS: `edgeRealtimeBaseUrl` → Edge. Cloud WS proxy sonraki. |

**Hedef iş akışı (ürün):** Müşteri QR’ı internet üzerinden **Cloud**’a gider; Cloud hangi restoran/Edge olduğunu çözer ve sipariş/durum trafiğini doğru Edge örneğine bağlar (offline dönemlerde Edge LAN davranışı aynı kalır).

**Şu anki yerel test akışı:** Edge `local` + lab açık → Flutter Web `/#/guest-lab?restaurantId=<uuid>` → masaya tıkla → `/guest/qr?r=&t=&k=` ile Edge guest API + WS (Cloud katmanı olmadan).

---

## 3. Operasyonel iş akışları (The Journey)

### Misafir (QR) — hedef vs mevcut

| Aşama | Hedef (Cloud-first) | Mevcut kod / test |
|-------|---------------------|-------------------|
| QR / link | Cloud public URL; restoran ve masa Cloud’da çözülür | QR PDF → `public-cloud-url` + `/r/...`; redirect → Flutter `/#/guest/qr?via=cloud` |
| Oturum | Cloud veya Edge BFF; token güvenli dağıtım | Edge `TableGuestToken` + `GET …/guest/.../session` |
| Menü / sepet | Cloud proxy → Edge veya sync cache (tasarım kararı) | Edge `GET …/menu`, sepet istemci tarafı |
| Sipariş | Cloud → doğru Edge `POST …/orders` | Edge’e doğrudan `POST …/orders` |
| Durum | WS/REST Edge veya Cloud agregasyonu | Edge `ws://…/ws/v1/guest?…` + REST `orders/open` |

| Adım | Durum | Not |
|------|--------|-----|
| QR → oturum / masa | **Kısmen** | Token + session API; Flutter lab ile toplu masa testi. |
| Sepet → onay → mutfak | **Kısmen** | Edge’de sipariş + mutfak WS + `kitchen_landing` gerçek kuyruk. Tam otomasyon (sipariş kapanışı, mutfak dışı roller) **kısmen**. |
| Alındı / hazır bildirimleri | **Kısmen** | Mutfak + misafir WS; garson hazır paneli + push. |
| Ödeme (ürün/tutar/toplam, bahşiş) | **Kısmen** | Kasa: kalan / sabit tutar / **satır seçimi** (`PRODUCT_LINES`). Bahşiş + iade. Fatura entegrasyonu **eksik**. |
| Masa kapanışı | **Kısmen** | `close-session`: standart, zorla, bakiye bırak → `DEFERRED`. Edge **`GET /cashier/balance-report`** + kasa/admin UI. Cloud raporlama **eksik**. |

### 3.1 Masa kapat — mevcut ve gelecek senaryolar

**Şu an:** Kasiyer, sipariş detayında bakiye sıfırlandığında **Masayı kapat** ile masa serbest bırakılır. v2 başlangıcı olarak restoran admini, açık bakiye varken **Zorla kapat** diyaloğundan `FORCE_CLOSE_UNPAID` + `reasonCode` + not gönderebilir; işlem `table_closure_audit_logs` tablosuna yazılır.

**Gelecek (ürün kararı bekleyen):** Sahada “masa kapat” çoğu zaman ödeme tamamlanmadan da istenir. Planlanan genişletme alanları:

| Senaryo | Örnek durum | Taslak davranış |
|---------|-------------|-----------------|
| **Zorunlu kapat (force)** | Müşteri ayrıldı, hesap ödenmeyecek / şikâyet | Restoran admini açık bakiye ile kapatabilir; audit’te `remaining_principal` + `balance_disposition` (`VOID` / `WRITE_OFF`). Kasa zorla kapat diyaloğunda seçim. |
| **Bakiye bırakarak kapat** | Kurumsal hesap, sonradan fatura | Masa serbest; sipariş `OPEN` veya `DEFERRED` kalır; Cloud sync’e işaret. |
| **Masayı devret** | Yanlış masa, birleştirme | **Yapıldı:** `POST /waiter/tables/transfer-orders`. |
| **Kısmi ödeme sonrası kapat** | Nakit yetmedi, kalan silindi | Kalan tutar indirim/iptal kodu; kapatma onayı. |
| **Garson / yönetici kapat** | Kasa meşgul, servis masayı boşalttı | Rol bazlı endpoint; kasa dışı UI veya PIN onayı. |

**Teknik notlar (implementasyon öncesi):**
- `TableClosureService` politika tabanlı olmalı (`ClosurePolicy`: `STRICT_PAID`, `FORCE`, `DEFER_BALANCE`, …).
- Her zorunlu kapatma: `closedBy`, `reasonCode`, `timestamp` (fiscal/audit için).
- Cloud raporlama: yazılan / ertelenen bakiyeler ayrı görünür olmalı.

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
| `cloud` | Auth, sync, admin restoran paneli, **`PublicGuestRestController`** (misafir BFF → Edge), güvenlik + CORS. |
| `edge` | Auth (süperadmin yok), guest (REST + `/guest` SPA + `manifest.json` + **misafir lab**), layout, QR, kitchen, billing, print, setup, sync, güvenlik + CORS. |
| `edge_frontend` | Personel: login, admin (kat/QR/**menü**/seçenek/personel), garson/mutfak/kasa Edge API ile **kısmen** bağlı; setup sihirbazı. **Misafir:** `/guest-lab`, `/guest/qr` (giriş gerektirmez). |
| `cloud_frontend` | Süperadmin: login + restoran listesi/abonelik + Edge çevrimiçi durumu + restoran oluşturma/silme. |
| `config/` | Örnek `quickserve-config.sample.yaml`. |
| `docs/` | [QUICKSERVE_PLAN.md](./QUICKSERVE_PLAN.md), [CLOUD_EDGE_INTERNET.md](./CLOUD_EDGE_INTERNET.md) (Cloud↔Edge internet / tunnel / URL’ler). |

---

## 8. Öncelik önerisi (sıradaki işler — taslak)

1. ~~Garson: masa → menü → sepet → Edge sipariş API.~~ *(Edge API + `waiter_landing` temel akış tamam; seçenekli ürün / harita sonraki.)*  
2. ~~Mutfak: gerçek kuyruk + durum butonları + (isteğe bağlı) WS.~~ *(Temel kuyruk + butonlar + WS yenileme tamam; garson push / servis çıkışı API sonraki.)*  
3. ~~Kasa: açık adisyon + `BillingController` ile ödeme.~~ *(Açık liste API + `cashier_landing` kalan tahsilat ve belirli tutar tahsilatı; satır bazlı ödeme/iade sonraki.)*  
4. Misafir: Cloud BFF + QR PDF Cloud URL + redirect tamam (localhost). Sırada: `guest.web-base-url` prod, Cloud WS proxy, gerçek internet (WiFi IP / tunnel). Statik `/guest` yedek.  
5. ~~Cloud: Edge listesi / last seen API + `cloud_frontend` ekranı.~~ *(Temel panel tamam; eşik/heartbeat ayarı ve edge-id’siz restoranlar için ayrı liste isteğe bağlı.)*  
6. ~~**Masa kapat v2:** Edge bakiye raporu.~~ *(Tamam; Cloud süperadmin raporu sonraki.)*  
7. ~~Cloud: restoran **oluşturma/silme** süperadmin için.~~ *(Backend `POST` + soft-delete `DELETE`; `cloud_frontend` form ve onaylı silme tamam.)*

*(Öncelik ürün kararına göre değiştirilir; değişince bu bölümü güncelleyin.)*

---

## 9. Güncelleme günlüğü

| Tarih | Özet | Modül |
|-------|------|--------|
| 2026-05-19 | Dokümantasyon: [CLOUD_EDGE_INTERNET.md](./CLOUD_EDGE_INTERNET.md) — internette Cloud↔Edge trafik hatları, URL config, tunnel/port-forward, prod checklist, sorun giderme. | docs |
| 2026-05-19 | Ürün resmi: `products.image_path` (V19), `ProductImageService` + public media endpoint; admin `POST/DELETE …/products/{id}/image`; `imageUrl` misafir/garson/admin menü DTO’larında; Flutter admin (yükle/kaldır + küçük resim), misafir QR ve garson menü kartlarında görsel. | common, edge, edge_frontend, docs |
| 2026-05-19 | Menü sıralama: `sort_index` (V18) menü/ürün; `PUT …/reorder` API’leri; admin Menü + Seçenekler ekranında sürükle-bırak. | common, edge, edge_frontend, docs |
| 2026-05-19 | Garson servis çıkışı: `POST …/waiter/orders/{id}/lines/{id}/delivered` → `KitchenLineStatus.DELIVERED`; hazır paneli Edge’e yazar. | edge, common, edge_frontend, docs |
| 2026-05-19 | Masa devret: `TableOrderTransferService`, `POST /api/v1/waiter/tables/transfer-orders`; garson masa kartı menüsü. | edge, edge_frontend, docs |
| 2026-05-18 | Garson salon haritası: `WaiterFloorMapScreen` + layout REST/WS; masa dokun → sipariş. | edge_frontend, docs |
| 2026-05-18 | Bakiye raporu: `GET /cashier/balance-report` (DEFERRED + audit); `ClosureBalanceReportScreen` kasa + admin. | edge, edge_frontend, common, docs |
| 2026-05-18 | Kasa satır bazlı ödeme: ödeme sheet’inde **Satır** modu, çoklu satır seçimi + `PRODUCT_LINES` API. | edge_frontend, docs |
| 2026-05-18 | Günlük iş paketi: ödeme iadesi; `DEFER_BALANCE` + `OrderStatus.DEFERRED`; kat planı WS editörde + siparişte OCCUPIED; QR token rotate/revoke. | edge, edge_frontend, common, docs |
| 2026-05-18 | Menü yönetimi: `MenuAdminController` (`/menus/tree`, menü/ürün CRUD, soft-delete + seçenek cascade); `menu_admin_screen` + Menü sekmesi. | edge, edge_frontend, docs |
| 2026-05-18 | Misafir Faz 2: QR PDF `public-cloud-url`; lab `cloudGuestUrl`; Cloud redirect HTML yardımı; lab varsayılan Cloud BFF. | edge, cloud, edge_frontend, config, docs |
| 2026-05-18 | Cloud misafir BFF: `PublicGuestRestController` Edge proxy; `RestaurantEdgeResolver`; `GET /r/...` yönlendirme; Flutter `via=cloud` + misafir lab anahtarı; session’da `edgeRealtimeBaseUrl`. | cloud, edge_frontend, docs |
| 2026-05-18 | Masa kapat v2: `TableClosureBalanceDisposition` (`VOID`/`WRITE_OFF`), `V17` audit kolonu; zorla kapatmada bakiye sınıflandırması zorunlu; kasa UI seçimi. | common, edge, edge_frontend, docs |
| 2026-05-18 | Restoran admin personel yönetimi: listeleme + personel ekleme/düzenleme/silme + şifre sıfırlama; son admini koruyan backend kontrolleri. | edge, edge_frontend, docs |
| 2026-05-18 | Cloud süperadmin restoran silme: `DELETE /api/v1/admin/restaurants/{id}` soft-delete; dashboard kartlarında onaylı silme aksiyonu. | cloud, cloud_frontend, docs |
| 2026-05-18 | Kasa kısmi ödeme UI: ödeme sheet’inde `REMAINDER` / `FIXED_AMOUNT` seçimi, tutar validasyonu ve backend `FIXED_AMOUNT` ödeme gövdesi. | edge_frontend, docs |
| 2026-05-18 | Cloud süperadmin restoran oluşturma: `POST /api/v1/admin/restaurants`, validasyonlu create request, `cloud_frontend` “Restoran ekle” diyaloğu; yeni restoran `NEVER_SEEN` Edge durumu ile listelenir. | cloud, cloud_frontend, docs |
| 2026-05-18 | Masa kapat v2 başlangıcı: `TableClosurePolicy`, `TableClosureReasonCode`, `table_closure_audit_logs`; admin için açık bakiyeli `FORCE_CLOSE_UNPAID` akışı ve kasa UI’da reason/note diyaloğu. | common, edge, edge_frontend, docs |
| 2026-05-15 | Cloud süperadmin: restoran listesine Edge durumu (`AdminEdgeMonitoringService`, `edgeStatus`, son hello/URL); `cloud_frontend` kartlar + 30 sn yenileme. Edge: `EdgeHeartbeatScheduler` periyodik hello. Plan: § 3.1 ödeme öncesi masa kapat senaryoları. | cloud, edge, cloud_frontend, docs |
| 2026-05-15 | Masa kapanışı (bakiye=0): `TableClosureService`, `POST …/cashier/tables/{id}/close-session`; kasa WS yenileme. Garson seçenekli ürün + admin seçenek CRUD. Garson hazır bildirimi (`ready-lines`, waiter WS). | edge, edge_frontend, common, docs |
| 2026-05-13 | Flutter Web: `HashUrlStrategy` + `/` → `/login` yönlendirmesi; `/#/guest-lab` boş sayfa (path/hash uyumsuzluğu) giderildi; `go_router` `errorBuilder`. | edge_frontend, docs |
| 2026-05-13 | Misafir: Edge **misafir lab** API (`guest-lab-enabled`) + Flutter `/guest-lab` (masa listesi) ve `/guest/qr` (token’lı menü/sepet/sipariş/WS + option-wizard); `go_router` misafir rotaları girişsiz; plan dokümanı Cloud-first misafir hedefi + yerel test linki. | edge, edge_frontend, docs |
| 2026-05-13 | Misafir: `GET …/guest/.../orders/open`, `GuestOrderStatusResponse`; `GuestMenuService` + repo sorgusu; `/guest` SPA Durum sekmesi (REST + WS birleşimi), `manifest.json`. | edge, common, docs |
| 2026-05-13 | Kasa: `GET /api/v1/cashier/open-orders`, `CashierOpenOrdersService` + `RestaurantOrderRepository` status filtresi; `cashier_landing` + `edge_cashier_api` (`BillingController` özet/ödeme). | edge, common, edge_frontend, docs |
| 2026-05-13 | Mutfak: `GET /api/v1/kitchen/queue`, `KitchenQueueService`; `KitchenStationController` tabanı `/api/v1/kitchen` (POST yolları aynı); satır işlemlerinde JWT `restaurantId` doğrulaması; `GuestOrderRealtimeBridge` mutfak WS `LINE_KITCHEN_STATUS`; `kitchen_landing` + `edge_kitchen_api` REST/WS; `RestaurantOrderRepository` OPEN sorgusu. | edge, common, edge_frontend, docs |
| 2026-05-13 | Garson: Edge `WaiterRestController` (`/api/v1/waiter/tables`, `/menu`, `/orders`); `QrOrderService` + `GuestOrderRealtimeBridge` masa siparişlerinde mutfak push; `CreateQrOrderRequest.channel`; `edge_frontend` garson ekranı API + sepet. | edge, edge_frontend, docs |
| 2026-05-13 | İlk sürüm: ürün metni + mevcut kod durumu + bakım kuralları; Flyway `V14` local seed (V11 çakışması giderildi); Cloud/Edge frontend ayrımı, planlanan eksikler işlendi. | docs |

<!-- Yeni satırlar tablonun ÜSTüne ekleyin (en yeni üstte). -->
