# QuickServe — Fool-Proof Sağlamlaştırma Planı

**Oluşturulma:** 2026-05-31
**Amaç:** Pilot restoran açılmadan tamamlanması ŞART olan dayanıklılık eksikliklerinin atomik, takip edilebilir planı. Her madde tamamlandığında bu dokümanı işaretle.

**İlişkili belgeler:**
- [QUICKSERVE_ROADMAP.md](./QUICKSERVE_ROADMAP.md) — 6 fazlı genel yol haritası (FAZ 1 sağlamlaştırma bu plandaki maddeleri içerir)
- [QUICKSERVE_PLAN.md](./QUICKSERVE_PLAN.md) — Ürün ve canlı kod durumu

---

## Bağlam (Niye bu plan?)

2026-05-29 fool-proof denetiminde 5 paralel kod incelemesi ile **~30 KRİTİK + ~30 ÖNEMLİ** dayanıklılık eksikliği tespit edildi. Bu eksiklikler 5 eksene yayılı:

1. **Sipariş & Ödeme** — idempotency yok, optimistic lock exception handler yok, fiscal tx içine sızmış, layout broadcast commit öncesi
2. **Edge ↔ Cloud Sync** — `@PreUpdate` LWW eziyor, outbox backoff fiilen yok, DEAD letter status yok, NTP/TZ tanımsız
3. **WebSocket** — handshake'te JWT yok (internetten event sızıntısı), Flutter reconnect yok, head-of-line blocking
4. **Flutter UX** — `.timeout()` yok, 401 global handler yok, kasada busy flag eksik (frontend çift POST riski), WS reconnect yok
5. **Operasyon** — Actuator bağımlılığı yok, print queue in-memory (restart = fiş kaybı), Postgres backup yok, logback yok

Bu plan, **pilot-hazır** olabilmek için minimum 15 maddeyi sprint'lere böler. Tüm bulguların tam listesi 2026-05-29 chat transcript'inde mevcut; bu doküman uygulama planıdır.

---

## Yöntem

- Sprintler: **S0 (mali güvenlik)**, **S1 (sync + WS güvenlik)**, **S2 (UX dayanıklılık)**, **S3 (operasyon)**
- Her madde **F-numarası** taşır (F1..F15). Yapıldıkça `[x]` işaretle ve commit hash ekle.
- Her madde için: **Eksen / Süre / Bağımlılık / Etki / Adımlar / Doğrulama / Risk / Status**
- "Süre" tek geliştirici çalıştığı varsayım ile; paralelleştirilebilir maddeler tabloda işaretli.

---

## Üst Seviye İlerleme Tablosu

| # | Madde | Eksen | Sprint | Süre | Bağımlılık | Status |
|---|---|---|---|---|---|---|
| F1 | GlobalExceptionHandler (optimistic lock → 409) | Sipariş | S0 | 2 sa | — | ⬜ |
| F3 | Payment/Order DTO validation (@Digits/@Max/@Size) | Sipariş | S0 | 1 sa | F1 | ⬜ |
| F2 | Idempotency-Key middleware + tablo | Sipariş | S0 | 1 gün | F1 | ⬜ |
| F4 | FloorLayout broadcast → AFTER_COMMIT | Sipariş | S0 | 2 sa | — | ⬜ |
| F5 | Fiscal kaydı outbox / REQUIRES_NEW | Sipariş | S0 | 3 sa | — | ⬜ |
| F11 | Flutter kasiyer/guest busy flag | UX | S0 | 4 sa | — | ⬜ |
| F6 | BaseEntity @PreUpdate LWW-aware | Sync | S1 | 4 sa | — | ⬜ |
| F7 | SyncOutbox FAILED/DEAD + backoff filter | Sync | S1 | 4 sa | — | ⬜ |
| F8 | WS handshake JWT ticket | WS | S1 | 3 sa | — | ⬜ |
| F9 | Flutter ReconnectingWsClient + lifecycle | UX/WS | S2 | 1 gün | F8 | ⬜ |
| F10 | Merkezi ApiClient (timeout + 401 interceptor) | UX | S2 | 1 gün | — | ⬜ |
| F12 | Actuator + Docker healthcheck | Ops | S3 | 3 sa | — | ⬜ |
| F13 | Print outbox (DB-backed) | Ops | S3 | 1 gün | — | ⬜ |
| F14 | Postgres backup script + systemd timer | Ops | S3 | 1 gün | — | ⬜ |
| F15 | logback-spring + docker logging.options | Ops | S3 | 2 sa | — | ⬜ |

**Toplam: ~9-10 iş günü** (S0+S1 paralelleştirilirse ~1 hafta, S2+S3 paralel +1 hafta).

---

## SPRINT S0 — Mali Güvenlik (öncelik 1, ~2 gün)

Bu sprint pilot restoranın **ilk gece** patlamamasını garanti eder. Çift sipariş, çift fatura, kasa açığı, hayalet boş masa risklerini sıfırlar.

---

### F1 — `GlobalExceptionHandler` (`@RestControllerAdvice`)

- **Eksen:** Sipariş & Ödeme
- **Süre:** 2 saat
- **Bağımlılık:** —
- **Etki:** KRİTİK (UX) — kasiyer "ödeme alındı mı?" belirsizliğini sonlandırır

**Sorun:**
`common/.../BaseEntity.java:34-36`'da `@Version` zaten var → optimistic lock JPA seviyesinde çalışıyor. **Ama** Spring default davranışı `ObjectOptimisticLockingFailureException` → HTTP 500. `Grep("@ExceptionHandler|@RestControllerAdvice")` → 0 sonuç.

**Adımlar:**
1. `common/src/main/java/com/qr/common/web/GlobalExceptionHandler.java` oluştur.
2. Handler'lar:
   - `ObjectOptimisticLockingFailureException`, `OptimisticLockingFailureException` → 409 + `ProblemDetail{title: "stale_resource", message: "Bu kayıt başka bir kullanıcı tarafından güncellendi, sayfayı yenileyin"}`
   - `MethodArgumentNotValidException`, `ConstraintViolationException` → 400 + alan bazlı hata listesi
   - `DataIntegrityViolationException` → 409 + jenerik "veri bütünlüğü ihlali"
   - `ResponseStatusException` → kendi status'una saygı (zaten Spring native handler var, ama uniform format için override)
   - `Exception` (catch-all) → 500 + log.error + correlationId
3. `@RestControllerAdvice(basePackages = "com.qr")` — hem cloud hem edge'de aktif.
4. Response gövdesi: `RFC 7807 ProblemDetail` (Spring 6 built-in).

**Doğrulama:**
- [ ] Edge testleri `mvn -pl edge test` → 10/10 geçer
- [ ] Manuel test: aynı `RestaurantOrder` üzerinde iki paralel `BillingPaymentService.pay` → ikinci çağrı **HTTP 409** döner, 500 değil
- [ ] Geçersiz `tipAmount: -5` → 400 + `{"field":"tipAmount","message":"must be >= 0"}` (F3 ile birleşik test)

**Risk:**
- Mevcut endpoint'lerden bazıları zaten `try/catch` ile exception yutuyor olabilir; handler tetiklenmez. Tüm `BillingController`, `WaiterRestController`, `CashierRestController`, `QrOrderController` review edilmeli — gereksiz try/catch'ler kaldırılmalı.

**Status:** ⬜ (commit: —)

---

### F3 — Payment/Order DTO `@Digits/@DecimalMax/@Max/@Size` validasyonları

- **Eksen:** Sipariş & Ödeme
- **Süre:** 1 saat
- **Bağımlılık:** F1 (handler validasyon hatasını 400'e map'liyor)
- **Etki:** KRİTİK — overflow, scale bozulması, DoS riski

**Sorun:**
- `edge/.../billing/api/ProcessPaymentRequest.java:13-21` — `tipAmount`, `fixedAmount` çıplak `BigDecimal`. Üst sınır yok.
- `Payment.amount` ve `tipAmount` DB'de `precision=12 scale=2`. Aşma → `DataIntegrityViolationException` → 500 (F1 olmadan).
- `BillingPaymentService:147-150` `tip < 0` kontrolü var ama scale=3 sessizce yuvarlanıyor → mali audit'te güven kaybı.
- `edge/.../qr/api/CreateQrOrderRequest.java:17,29` — `quantity` ve `lines.size()` sınırsız. `quantity = 100_000_000` → BigDecimal × overflow. `lines = [5000 satır]` → DoS.

**Adımlar:**
1. `ProcessPaymentRequest`:
   ```java
   @DecimalMin(value = "0", inclusive = false) @DecimalMax("9999999999.99")
   @Digits(integer = 10, fraction = 2)
   BigDecimal fixedAmount,
   @DecimalMin(value = "0", inclusive = true) @DecimalMax("999999.99")
   @Digits(integer = 6, fraction = 2)
   BigDecimal tipAmount,
   ```
2. `LinePayRequest.amount` aynı pattern (`@DecimalMin > 0`, `@DecimalMax`, `@Digits`).
3. `CreateQrOrderRequest`:
   ```java
   @Positive @Max(9999) int quantity,
   @NotEmpty @Size(max = 200) @Valid List<QrOrderLineRequest> lines,
   ```
4. `RefundPaymentRequest` (varsa) — aynı tip kontrolleri.
5. Controller'larda `@Valid` annotation'larının yerinde olduğunu doğrula.

**Doğrulama:**
- [ ] `curl -X POST .../payments -d '{"tipAmount": -1, ...}'` → 400
- [ ] `curl -X POST .../payments -d '{"fixedAmount": 99999999999999.99, ...}'` → 400
- [ ] `curl -X POST .../qr/orders -d '{"lines": [...10001 satır]}'` → 400
- [ ] `curl -X POST .../qr/orders -d '{"lines":[{"quantity": 999999}]}'` → 400
- [ ] Edge testleri geçer

**Risk:**
- Mevcut frontend bu validasyonları biliyor mu? Genelde kullanıcı yüksek tutar girmiyor ama integration test'lerde fixture'lar 5 basamağı geçiyorsa kırılır — kontrol et.

**Status:** ⬜ (commit: —)

---

### F2 — `X-Idempotency-Key` middleware + `idempotency_keys` tablosu

- **Eksen:** Sipariş & Ödeme
- **Süre:** 1 gün
- **Bağımlılık:** F1
- **Etki:** KRİTİK — çift sipariş + çift fatura imkansız hale gelir

**Sorun:**
`Grep("idempotency|Idempotency")` workspace genelinde → sadece `.env.example` (bootstrap için, REST için değil). Hiçbir POST'ta idempotency koruması yok:
- `POST /api/v1/qr/orders` — misafir "Sipariş Ver"e iki kez basarsa çift sipariş + mutfağa iki ticket
- `POST /api/v1/waiter/orders` — garson aynı
- `POST /api/v1/.../billing/payments` — kasiyer çift tıklarsa kısmi modda **çift tahsilat**
- `POST /api/v1/.../close-session` — masa kapatma çift tıklaması

**Adımlar:**

1. **Migration** (`common/src/main/resources/migration-postgresql/V23__idempotency_keys.sql`):
   ```sql
   CREATE TABLE idempotency_keys (
       id            UUID         PRIMARY KEY,
       key           VARCHAR(128) NOT NULL,
       endpoint      VARCHAR(255) NOT NULL,
       request_hash  VARCHAR(64)  NOT NULL,
       response_body TEXT,
       response_status INT,
       created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
       UNIQUE (key, endpoint)
   );
   CREATE INDEX idx_idempotency_keys_created_at ON idempotency_keys (created_at);
   ```
   - Aynı migration'ın H2 versiyonu (`migration-local`) için TIMESTAMPTZ → TIMESTAMP.

2. **Entity + Repository** (`common/.../persistence/entity/IdempotencyKey.java`, `IdempotencyKeyRepository.java`).

3. **Filter** (`common/.../web/IdempotencyFilter.java` — Servlet filter):
   - Sadece şu endpoint'lerde aktif: `POST /api/v1/qr/orders`, `POST /api/v1/waiter/orders`, `POST /api/v1/.../payments`, `POST /api/v1/.../close-session`, `POST /api/v1/.../refund`.
   - `X-Idempotency-Key` header **zorunlu** (yoksa 400). UUID format kontrolü.
   - Filter logic:
     - Body'yi cache'le (`ContentCachingRequestWrapper`)
     - Body'nin SHA-256'sını al
     - DB'de `(key, endpoint)` ara:
       - **Yok** → request'i geçir, response'u cache'le, `INSERT idempotency_keys(key, endpoint, request_hash, response_body, response_status)`. Race koşulu için INSERT'te `ON CONFLICT DO NOTHING` (PG) ve sonra SELECT.
       - **Var ve `request_hash` eşleşiyor** → cached response'u dön (response_status + response_body)
       - **Var ama `request_hash` farklı** → 409 `{title: "idempotency_key_reuse", message: "Aynı key farklı body ile kullanıldı"}`
   - 24 saatten eski kayıtları nightly cleanup job ile sil (`@Scheduled(cron = "0 0 3 * * *")`).

4. **Edge security config**: filter'ı `SecurityFilterChain`'in security filter'larından **sonra** (auth + restaurantId resolve edildikten sonra) ekle. `OncePerRequestFilter` türet.

5. **Frontend (edge_frontend)** — her kritik POST'ta `Uuid().v4()` ile key üret, header'a ekle:
   - `qr_order_screen.dart` — `_submitOrder`
   - `waiter_landing_screen.dart` — sipariş ver
   - `cashier_landing_screen.dart` ve pay-sheet — tüm payment POST'ları
   - `_closeTable`, `_deferCloseTable`, `_forceCloseTable`, `_refundPayment`
   - Helper: `lib/api/idempotent_post.dart` — generic wrapper

6. **Acceptance & test**:
   - Unit test: filter `IdempotencyFilterTest` (yok, mevcut, farklı body)
   - Integration test: aynı key ile iki POST → ikincisi cached response döner, mutfak fişi tek seferlik basılır
   - Manuel test: misafir QR ekranında "Sipariş Ver"e 5 kez ardarda bas → sadece 1 sipariş oluşur

**Doğrulama:**
- [ ] `(key, endpoint)` UNIQUE çakışmasında 409 doğru dönüyor
- [ ] `X-Idempotency-Key` eksikse 400
- [ ] Cached response status code da korunuyor (örn. 201 Created → 201, 200 değil)
- [ ] Cleanup job çalışıyor (`SELECT count(*) FROM idempotency_keys WHERE created_at < now() - interval '24 hours'` → 0)
- [ ] Edge testleri geçer

**Risk:**
- **Disk büyümesi**: günde 10000 sipariş × 30 gün cleanup gecikmesi = 300K satır. PG kolayca kaldırır ama cleanup job hata atarsa şişer. Cleanup için `@SchedulerLock` (varsa) kullan ki iki Edge node aynı anda silmesin.
- **Filter ordering**: Spring Security chain'inde yanlış sıralanırsa auth gerektirmeyen misafir endpoint'inde restaurant context henüz çözülmemiş olabilir. Test gerekli.
- **Frontend retry**: HTTP timeout sonrası retry yapan istemci aynı key ile gelmeli; ApiClient'a (F10) entegre etmek temiz çözüm. F10'dan önce yapılıyorsa manuel key üretimi sayfalarda tekrarlanır.

**Status:** ⬜ (commit: —)

---

### F4 — `FloorLayoutService.updateAvailability` broadcast'ini `AFTER_COMMIT`'e taşı

- **Eksen:** Sipariş & Ödeme
- **Süre:** 2 saat
- **Bağımlılık:** —
- **Etki:** ÖNEMLİ — hayalet boş masa senaryosunu önler

**Sorun:**
`edge/.../layout/FloorLayoutService.java:132-144` — `updateAvailability` metodu `layoutSessionRegistry.broadcast(...)` çağrısını **transaction commit'inden ÖNCE** yapıyor. Çağrı yerleri:
- `QrOrderService.placeOrder:166-167`
- `TableClosureService.releaseTable:239`
- `TableOrderTransferService.transferOpenOrders:108`

`BillingPaymentService.pay`'de `tryReleaseTableIfIdle` çağrısından **sonra** hala `recordAdisyonAttempt` çalışıyor (DB I/O, RuntimeException atabilir). Bu durumda parent tx rollback olur ama layout WS clients masayı zaten EMPTY broadcast etmiş olur → garson yeni misafir oturtur, gerçekte adisyon hala açık.

**Adımlar:**
1. `edge/.../layout/events/TableAvailabilityChangedEvent.java` oluştur:
   ```java
   public record TableAvailabilityChangedEvent(UUID restaurantId, FloorAvailabilitySnapshot snapshot) {}
   ```
2. `FloorLayoutService.updateAvailability` — broadcast satırını kaldır, yerine:
   ```java
   eventPublisher.publishEvent(new TableAvailabilityChangedEvent(restaurantId, snap));
   ```
3. Ayrı bridge sınıfı (`edge/.../layout/events/LayoutBroadcastBridge.java`):
   ```java
   @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
   public void onAvailabilityChanged(TableAvailabilityChangedEvent ev) {
       layoutSessionRegistry.broadcast(ev.restaurantId(), toJson(ev.snapshot()));
   }
   ```
4. Pattern referansı: `edge/.../guest/events/GuestOrderRealtimeBridge.java:78, 94, 154, 215` — proje zaten bu paterni doğru uyguluyor (kitchen `NEW_GUEST_ORDER`, line status, vb.).

**Doğrulama:**
- [ ] Edge testleri geçer
- [ ] Manuel senaryo: `BillingPaymentService.pay` içinde fiscal save'i mock'la fırlat → ödeme rollback olur, layout broadcast yayınlanmaz (kasa UI eski state'i korur)
- [ ] Mevcut "masa OCCUPIED olunca garson haritasında anlık görünür" akışı bozulmaz

**Risk:**
- AFTER_COMMIT içindeki kod RuntimeException atarsa broadcast kaybolur (transaction'a etki etmez ama UI'da güncellenmemiş kalır). Log.error + retry yok — kabul edilebilir trade-off, WS reconnect (F9) zaten state'i resync edecek.

**Status:** ⬜ (commit: —)

---

### F5 — Fiscal kaydı outbox / `REQUIRES_NEW` propagation

- **Eksen:** Sipariş & Ödeme
- **Süre:** 3 saat
- **Bağımlılık:** —
- **Etki:** ÖNEMLİ — "para alındı ama DB'de yok" senaryosunu kaldırır

**Sorun:**
`edge/.../billing/BillingPaymentService.pay:215` → `fiscalComplianceService.recordAdisyonAttempt(...)` çağrısı, parent `@Transactional`'a katılır. İçinde 2 kez `fiscalAuditLogRepository.save(row)` var; DB connection broken senaryosunda `RuntimeException` → parent tx rollback → **ödeme DB'ye yazılmaz** ama POS terminali parayı çoktan almıştır + F1'den sonra Ö1 düzeltildi diyelim, hala mali risk.

**Adımlar (Seçenek A — minimum invaziv, önerilen):**
1. `FiscalComplianceService.recordAdisyonAttempt` metoduna:
   ```java
   @Transactional(propagation = Propagation.REQUIRES_NEW, noRollbackFor = Exception.class)
   ```
2. `BillingPaymentService.pay` içinde çağrıyı try/catch ile sar:
   ```java
   try {
       fiscalComplianceService.recordAdisyonAttempt(...);
   } catch (Exception ex) {
       log.error("Fiscal compliance record failed for payment {}", payment.getId(), ex);
   }
   ```

**Adımlar (Seçenek B — outbox pattern, daha sağlam ama daha pahalı):**
1. `BillingPaymentService.pay` içinde:
   ```java
   eventPublisher.publishEvent(new PaymentRecordedEvent(payment.getId(), ...));
   ```
2. `FiscalComplianceListener`:
   ```java
   @TransactionalEventListener(phase = AFTER_COMMIT)
   @Async
   public void onPaymentRecorded(PaymentRecordedEvent ev) {
       fiscalComplianceService.recordAdisyonAttempt(ev);
   }
   ```
3. `@EnableAsync` aktif (zaten edge'de var).

**Karar:** Pilot için **Seçenek A** yeterli. Seçenek B 5+ restoran sonrası, gerçek e-fatura sağlayıcı entegrasyonunda gerekli.

**Doğrulama:**
- [ ] Edge testleri geçer
- [ ] Manuel: `fiscalAuditLogRepository`'i mock'la "DB down" simüle et → ödeme yine de DB'ye yazılır, log.error görünür
- [ ] `Payment` tablosunda yeni kayıt var, `fiscal_audit_logs` tablosunda yok — beklenen davranış

**Risk:**
- Fiscal kayıt kaybolursa mali audit'te eksik. Bu yüzden log.error + cloud'a sentry-benzeri alert (F12 sonrası eklenir) ŞART.

**Status:** ⬜ (commit: —)

---

### F11 — Flutter kasiyer/guest busy flag + buton disable

- **Eksen:** UX
- **Süre:** 4 saat
- **Bağımlılık:** —
- **Etki:** KRİTİK (mali) — F2'nin frontend tamamlayıcısı

**Sorun:**
Aşağıdaki kritik akışlarda `_busy`/`isLoading` flag yok, kullanıcı butona iki kez basabilir (F2 backend'te bunu engelliyor ama UX olarak kötü):
- `cashier_landing_screen.dart` → `_closeTable`, `_deferCloseTable`, `_forceCloseTable`, `_refundPayment`
- `qr_order_screen.dart` (edge guest) → `_submitOrder` (busy flag yok; cloud guest ✅ yapıyor)
- Refund detay sayfası

**Adımlar:**
1. Her ekran için:
   ```dart
   bool _busy = false;
   Future<void> _closeTable() async {
     if (_busy) return;
     setState(() => _busy = true);
     try {
       // ... existing logic
     } finally {
       if (mounted) setState(() => _busy = false);
     }
   }
   ```
2. Butonlarda:
   ```dart
   FilledButton.icon(
     onPressed: _busy ? null : _closeTable,
     icon: _busy
         ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
         : const Icon(Icons.check),
     label: const Text('Masayı kapat'),
   )
   ```
3. Edge guest `qr_order_screen.dart` `_submitOrder` için aynı.
4. **F2 bağlantısı**: Bu metodlar F2 ile birlikte yapılırsa idempotency-key üretimi de aynı try bloğunda. Ayrı yapılırsa ileride F2 entegre edilirken touch noktaları aynı.

**Doğrulama:**
- [ ] Manuel: kasada "Tahsil et" butonuna hızlı 5 kez bas → tek POST gider, UI loading gösterir
- [ ] Misafir QR'da "Sipariş Ver"e 5 kez bas → tek sipariş

**Risk:**
- `setState`'i unutursan `_busy` true kalır, kullanıcı bir daha tıklayamaz. `try/finally` ŞART.
- `mounted` check'i (dispose sonrası setState atmaz) ŞART.

**Status:** ⬜ (commit: —)

---

## SPRINT S1 — Sync + WS Güvenlik (~2 gün)

### F6 — `BaseEntity.@PreUpdate` LWW-aware

- **Eksen:** Sync
- **Süre:** 4 saat
- **Bağımlılık:** —
- **Etki:** KRİTİK — sync'in temel doğruluk garantisi

**Sorun:**
`common/.../BaseEntity.java:62-65`:
```java
@PreUpdate
protected void preUpdate() {
    this.updatedAt = LocalDateTime.now(); // <-- sync-incoming değeri eziyor
}
```
`SyncEntityMergeService.mergeXxx` metotları `existing.setUpdatedAt(incoming.getUpdatedAt())` çağırsa da JPA flush öncesi `@PreUpdate` bu değeri overwrite ediyor. Net etki: **stable kayıtlar bile sonsuz ping-pong'a giriyor** (Edge update eder → Cloud'a gönderir → Cloud `existing.updatedAt = incoming` der ama `@PreUpdate` Cloud now() ile ezer → Cloud "yeni" sayar → bir sonraki pull'da Edge'e geri gönderir → loop).

**Adımlar:**
1. ThreadLocal flag:
   ```java
   public final class SyncIngestContext {
       private static final ThreadLocal<Boolean> INGEST = ThreadLocal.withInitial(() -> false);
       public static void enter() { INGEST.set(true); }
       public static void exit() { INGEST.remove(); }
       public static boolean isIngesting() { return INGEST.get(); }
   }
   ```
2. `BaseEntity.preUpdate`:
   ```java
   @PreUpdate
   protected void preUpdate() {
       if (!SyncIngestContext.isIngesting()) {
           this.updatedAt = LocalDateTime.now(clock); // F-ileri: Clock bean kullan
       }
   }
   ```
3. `SyncEntityMergeService` veya pull işleyen yerde:
   ```java
   try {
       SyncIngestContext.enter();
       mergeEntity(...);
   } finally {
       SyncIngestContext.exit();
   }
   ```

**Alternatif (daha temiz ama büyük refactor):**
- `@PreUpdate` kullanma; her service'te explicit `entity.setUpdatedAt(...)` çağır. Risk: unutma → updatedAt güncellenmez.

**Karar:** ThreadLocal pattern güvenli ve geri uyumlu.

**Doğrulama:**
- [ ] Edge testleri geçer
- [ ] Manuel: Cloud → Edge pull yap, aynı entity'nin `updatedAt`'i değişmemiş olmalı; Edge → Cloud push'ta da aynı timestamp gitmeli
- [ ] Loop testi: aynı entity'yi 5 dakika boyunca izle, sync_outbox'a tekrar düşmemeli

**Risk:**
- ThreadLocal cleanup unutulursa async task'larda yanlış davranır. `try/finally` ŞART. `@Async` metotlarda da set/clear gerekli.

**Status:** ⬜ (commit: —)

---

### F7 — `SyncOutbox` `FAILED/DEAD_LETTER` + backoff filter

- **Eksen:** Sync
- **Süre:** 4 saat
- **Bağımlılık:** —
- **Etki:** KRİTİK — perma-fail satırların disk yakmasını önler

**Sorun:**
- `edge/.../sync/domain/SyncOutboxStatus.java` enum'unda sadece `PENDING`, `SENDING`. `FAILED`, `DEAD_LETTER` yok.
- `SyncOutboxRepository.findTop50ByStatusOrderByCreatedAtAsc(PENDING)` — `next_attempt_at` filtresi içermiyor (`SyncOutboxRepository.java:13`).
- `EdgeSyncService.java:335-336`'da `nextAttemptAt` set ediliyor ama sorguda kullanılmıyor → backoff fiilen yok.
- `drainOutbox` perma-fail satırı sonsuza retry eder.

**Adımlar:**
1. **Migration** (`common/.../migration-postgresql/V24__sync_outbox_dead_letter.sql`):
   ```sql
   ALTER TABLE sync_outbox ADD COLUMN IF NOT EXISTS attempt_count INT NOT NULL DEFAULT 0;
   ALTER TABLE sync_outbox ADD COLUMN IF NOT EXISTS last_error VARCHAR(1024);
   -- attempt_count ve next_attempt_at zaten var mı kontrol et; yoksa ekle
   ```
   (Mevcut şemada bu kolonlar varsa migration no-op olur — `IF NOT EXISTS` koruyor.)

2. **Enum genişlet** (`SyncOutboxStatus.java`):
   ```java
   public enum SyncOutboxStatus { PENDING, SENDING, FAILED, DEAD_LETTER }
   ```

3. **Repository** (`SyncOutboxRepository.java`):
   ```java
   @Query("SELECT o FROM SyncOutbox o WHERE o.status = :status AND (o.nextAttemptAt IS NULL OR o.nextAttemptAt <= :now) ORDER BY o.createdAt ASC")
   List<SyncOutbox> findReadyForRetry(@Param("status") SyncOutboxStatus status, @Param("now") LocalDateTime now, Pageable limit);
   ```
   Çağrı: `findReadyForRetry(PENDING, now, PageRequest.of(0, 50))`.

4. **`EdgeSyncService.drainOutbox`**:
   ```java
   } catch (Exception ex) {
       row.setAttemptCount(row.getAttemptCount() + 1);
       row.setLastError(truncate(ex.getMessage(), 1024));
       if (row.getAttemptCount() >= 20) {
           row.setStatus(SyncOutboxStatus.DEAD_LETTER);
           log.error("Sync outbox row {} moved to DEAD_LETTER after {} attempts", row.getId(), row.getAttemptCount());
       } else {
           row.setStatus(SyncOutboxStatus.PENDING);
           long backoffSeconds = Math.min(3600L, (long) Math.pow(2, row.getAttemptCount()));
           row.setNextAttemptAt(LocalDateTime.now(clock).plusSeconds(backoffSeconds));
       }
       syncOutboxRepository.save(row);
   }
   ```

5. **Admin endpoint** (`/api/v1/admin/sync-outbox/dead-letters`) — listele, manuel "retry" / "delete":
   - Süperadmin Cloud panelinden görünebilmesi için Cloud BFF üzerinden proxy.
   - Pilot için Edge admin UI'da da listelenmesi yeterli.

6. **Alarm**: `attempt_count = 20` olduğunda log.error + (F12 sonrası) Cloud'a event push.

**Doğrulama:**
- [ ] Edge testleri geçer
- [ ] Manuel: Cloud'u durdur, 10 dakika boyunca sipariş ver → `sync_outbox.next_attempt_at` exponential artmalı (5, 10, 20, 40, 80 sn... cap 3600 sn)
- [ ] 20 deneme sonrası `DEAD_LETTER` olur, polling artık o satırı çekmez
- [ ] Cloud geri gelince `PENDING + next_attempt_at <= now` olanlar tekrar gönderilir

**Risk:**
- Backoff kapanırsa Cloud geri gelse bile birikmiş 1 saatlik backoff'lar Edge'i yavaşlatır. Manuel "şimdi tekrar dene" admin butonu zorunlu.
- 20 deneme threshold'u: pilot için makul, üretimde pickle.

**Status:** ⬜ (commit: —)

---

### F8 — WebSocket handshake'te JWT ticket

- **Eksen:** WS Güvenlik
- **Süre:** 3 saat
- **Bağımlılık:** —
- **Etki:** KRİTİK — internetten event sızıntısı kapanır

**Sorun:**
- `edge/.../config/EdgeSecurityConfig.java:70` → `/ws/** permitAll`
- `KitchenPushWebSocketHandler.java:44-54` → sadece query string'den `restaurantId` okuyor.
- Edge Cloudflare tunnel ile internete açık (`deploy/edge/.env:25`). **Bilinen `restaurantId`** ile internetten herkes kitchen/cashier/waiter event'lerini dinleyebilir.

**Adımlar:**

1. **`WsTicketController`** (`edge/.../realtime/WsTicketController.java`):
   - `POST /api/v1/ws/tickets` (Auth gerekli, tüm roller için)
   - Body: `{role: KITCHEN|CASHIER|WAITER|GUEST, restaurantId: UUID, tableId?: UUID, token?: STRING}`
   - Validasyon:
     - JWT'den `restaurantId` çek → request body ile eşleşmeli
     - JWT role'u request role'u ile uyumlu olmalı
     - GUEST için JWT yok → `token` (TableGuestToken) doğrulanır
   - Response: `{ticket: <opaque>, expiresAt: <epoch>}` — opaque ticket DB'de değil, Redis veya in-memory `ConcurrentHashMap` (pilot için yeterli). TTL: 60 sn.

2. **Ticket store** (`WsTicketRegistry` — in-memory `ConcurrentHashMap<String, WsTicketContext>`, eviction 60 sn sonra):
   ```java
   public record WsTicketContext(UUID restaurantId, String role, Optional<UUID> tableId, Instant expiresAt) {}
   ```

3. **WS endpoint'lerinde ticket kontrolü** — tüm handler'lar (`KitchenPushWebSocketHandler`, `CashierPushWebSocketHandler`, `WaiterPushWebSocketHandler`, `LayoutWebSocketHandler`, `GuestWebSocketHandler`):
   - `afterConnectionEstablished`'da `URI.getQuery()`'den `ticket` parametresini al
   - `WsTicketRegistry.consume(ticket)` — geçerli ise tek seferlik kullan ve `WsTicketContext` ile session attribute'una koy; geçersiz ise 401 + connection close
   - Session'ın `restaurantId`'si artık ticket'tan gelir; query string'den DEĞİL.

4. **Frontend**:
   - WS açmadan önce `POST /api/v1/ws/tickets` çağır → ticket al
   - `ws://...?ticket=<value>` ile bağlan
   - WS reconnect olduğunda yeni ticket üret (F9 ile entegre)

5. **Cloud guest proxy uyumu**:
   - Misafir Cloud üzerinden geliyorsa Cloud BFF de ticket akışını proxy eder (`PublicGuestRestController`). Cloud kendi ticket üretir, Edge'in `WsTicketRegistry`'sine push eder mi? **Hayır**, çok karmaşık. Pilot için: Cloud → Edge tunnel JWT-imzalı header'la (`X-QuickServe-Cloud-Auth`) Edge'in ticket endpoint'ini çağırır, ticket'i misafire döner.
   - Bu Cloud-side iş F8'in S2'ye ertelenebilen kısmı. Edge-LAN için F8 yeterli.

6. **Geri uyumluluk**: Cloudflared tunnel arkasında olmayan Edge cihazları (sadece LAN) için ticket akışı zorunlu olsun mu? **Evet** — pilot restoran LAN'da çalıştığı süre boyunca da WS auth ŞART (içeri girmiş bir cihaz da dinlemesin).

**Doğrulama:**
- [ ] `ws://edge/ws/v1/kitchen/push?restaurantId=<known>` → 401 (ticket yok)
- [ ] `ws://edge/ws/v1/kitchen/push?ticket=<valid>` → bağlanır
- [ ] `ticket` 60 sn sonra reuse edilirse → 401
- [ ] Misafir token revoke edildikten sonra yeni ticket isteği → 401
- [ ] Edge frontend tüm WS bağlantıları (waiter, kitchen, cashier, layout, guest) yeni ticket akışına geçti

**Risk:**
- F9 (reconnect) ile birlikte yapılırsa daha temiz; ayrı yapılırsa frontend WS bağlantı yerlerinde manuel ticket çağrısı eklenir, refactor gerekir.
- Cloud-side guest WS akışı bu sprintte tamamlanmazsa pilot için "misafir LAN'da WS, internet'te REST polling" yapılabilir. Acceptable trade-off.

**Status:** ⬜ (commit: —)

---

## SPRINT S2 — UX Dayanıklılık (~2 gün)

### F9 — Flutter `ReconnectingWsClient` + `WidgetsBindingObserver`

- **Eksen:** UX / WS
- **Süre:** 1 gün
- **Bağımlılık:** F8 (yeni ticket akışını entegre eder)
- **Etki:** KRİTİK — wifi reconnect ve background→foreground geçişi çalışır

**Sorun:**
- `edge_frontend/lib/.../layout_ws_client.dart:35` → `onDone: () {}` (reconnect yok)
- `WidgetsBindingObserver` workspace genelinde 0 match → app pause/resume bildirimleri yakalanmıyor
- WS koptuğunda ekran ölü kalır, kullanıcı bilinçsizce eski veriye bakar

**Adımlar:**

1. **Generic helper** (`edge_frontend/lib/api/reconnecting_ws_client.dart`):
   ```dart
   class ReconnectingWsClient {
     ReconnectingWsClient({
       required this.urlBuilder, // Future<Uri> (yeni ticket alır)
       required this.onMessage,
       this.onConnected,
       this.onDisconnected,
       this.maxBackoff = const Duration(seconds: 30),
     });
     final Future<Uri> Function() urlBuilder;
     final void Function(dynamic msg) onMessage;
     final VoidCallback? onConnected;
     final VoidCallback? onDisconnected;
     final Duration maxBackoff;
     // ... internal state: WebSocketChannel?, attempt count, timer
     Future<void> connect();
     Future<void> close();
     void _scheduleReconnect(); // exponential: 1s, 2s, 4s, 8s, ..., cap maxBackoff
   }
   ```

2. **Mevcut WS client'ları refactor et**:
   - `layout_ws_client.dart`
   - `kitchen_ws_client.dart`
   - `cashier_ws_client.dart`
   - `waiter_ws_client.dart`
   - `guest_ws_client.dart`
   - Her birinde `urlBuilder` callback'i `POST /ws/tickets` çağırıp `ws://...?ticket=<value>` üretir

3. **`AppLifecycleManager`** (`edge_frontend/lib/app/app_lifecycle_manager.dart`):
   ```dart
   class _RootAppState extends State<RootApp> with WidgetsBindingObserver {
     @override
     void initState() {
       super.initState();
       WidgetsBinding.instance.addObserver(this);
     }
     @override
     void didChangeAppLifecycleState(AppLifecycleState state) {
       if (state == AppLifecycleState.resumed) {
         WsClientRegistry.instance.reconnectAll();
       } else if (state == AppLifecycleState.paused) {
         WsClientRegistry.instance.disconnectAll();
       }
     }
   }
   ```

4. **`WsClientRegistry`** — singleton, açık tüm `ReconnectingWsClient`'ları tutar.

5. **State resync** — reconnect sonrası kaçırılan event'leri çekmek için her ekran:
   ```dart
   onConnected: () async {
     await _refreshStateFromRest(); // örn. GET /orders/open
   },
   ```

6. **UI feedback** — "Bağlantı kuruluyor..." banner:
   - `onDisconnected` → setState ile sarı banner göster
   - `onConnected` → banner kaybolur

**Doğrulama:**
- [ ] Manuel: mutfak ekranı açıkken Edge'i restart et → 1-30 sn içinde otomatik yeniden bağlanır, kaçırılan event'ler `GET /kitchen/queue` ile gelir
- [ ] Manuel: garson telefonunu wifi'den çıkar → "Bağlantı yok" banner; wifi geri gelir → bağlantı + sipariş listesi taze
- [ ] Manuel: app background → 1 dk bekle → foreground → otomatik reconnect
- [ ] CPU/battery: reconnect spam yapmaz (exponential backoff doğru)

**Risk:**
- Resync için her ekranda farklı endpoint var → registry pattern (her ws client'ı kendi resync callback'i ile init etmek) gerekli
- Süperadmin Cloud panel'inin WS yok (sadece REST polling) → bu işten muaf

**Status:** ⬜ (commit: —)

---

### F10 — Merkezi `ApiClient` (timeout + 401 interceptor + global logout)

- **Eksen:** UX
- **Süre:** 1 gün
- **Bağımlılık:** —
- **Etki:** KRİTİK — spinner sonsuzluğu + sessiz token expiry deadlock'u biter

**Sorun:**
- `edge_frontend` ve `cloud_frontend`'de `http.get/post` çağrıları **direkt** yapılıyor, `.timeout(...)` yok
- 401 alındığında global redirect yok; kullanıcı boş ekrana bakar
- 5xx hata mesajı yok, ham status code SnackBar'a dökülür
- DNS / network unreachable → uncaught exception
- `cloud_frontend/app_router.dart`'ta `errorBuilder` yok

**Adımlar:**

1. **`ApiClient`** (`edge_frontend/lib/api/api_client.dart` + `cloud_frontend/lib/api/api_client.dart`):
   ```dart
   class ApiClient {
     ApiClient({required this.baseUrl, required this.authProvider, this.timeout = const Duration(seconds: 30)});
     final String baseUrl;
     final TokenProvider authProvider;
     final Duration timeout;

     Future<http.Response> get(String path, {Map<String, String>? headers}) async {
       return _send('GET', path, headers: headers);
     }
     Future<http.Response> post(String path, {Object? body, Map<String, String>? headers, String? idempotencyKey}) async {
       final mergedHeaders = {...?headers};
       if (idempotencyKey != null) mergedHeaders['X-Idempotency-Key'] = idempotencyKey;
       return _send('POST', path, body: body, headers: mergedHeaders);
     }
     Future<http.Response> _send(...) async {
       try {
         final res = await _client.send(req).timeout(timeout);
         if (res.statusCode == 401) {
           AuthEvents.instance.notifyExpired();
           throw ApiException(401, 'Oturum süresi doldu, lütfen tekrar giriş yapın');
         }
         if (res.statusCode >= 500) {
           throw ApiException(res.statusCode, 'Sunucu hatası, lütfen tekrar deneyin');
         }
         return res;
       } on TimeoutException {
         throw ApiException(0, 'Sunucu yanıt vermiyor, ağ bağlantınızı kontrol edin');
       } on SocketException {
         throw ApiException(0, 'Ağ bağlantısı yok');
       }
     }
   }
   ```

2. **`AuthEvents`** (singleton stream):
   ```dart
   class AuthEvents {
     static final instance = AuthEvents._();
     AuthEvents._();
     final _expired = StreamController<void>.broadcast();
     Stream<void> get onExpired => _expired.stream;
     void notifyExpired() => _expired.add(null);
   }
   ```

3. **Root app**: `AuthEvents.instance.onExpired.listen((_) => GoRouter.of(context).go('/login'))`

4. **`ApiException`** UI'da SnackBar pattern:
   ```dart
   try {
     await apiClient.post(...);
   } on ApiException catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
   }
   ```

5. **Mevcut `http.*` çağrılarını migrate et**:
   - `edge_frontend/lib/` altındaki ~30-40 yer (her ekranın kendi API helper'ı var)
   - Helper'ları (`edge_waiter_api.dart`, `edge_cashier_api.dart`, vb.) `ApiClient` üzerinden geçirecek şekilde refactor
   - Geri uyumluluk: helper'ların public signature'ları değişmemeli, sadece içlerinde `http.get` → `apiClient.get`

6. **`cloud_frontend/app_router.dart`** `errorBuilder` ekle:
   ```dart
   GoRouter(
     errorBuilder: (context, state) => Scaffold(
       body: Center(child: Text('Sayfa bulunamadı: ${state.uri}')),
     ),
     ...
   )
   ```

7. **JWT exp parse**: `TokenProvider`'da JWT payload decode et, exp < now + 60s ise refresh tetikle. Refresh endpoint backend'de yoksa (kontrol et) bu kısım F10'dan sonra ayrı bir madde olabilir. Şimdilik exp dolunca 401 alındığında F10'un kendi 401 handler'ı çalışsın.

**Doğrulama:**
- [ ] Manuel: Edge backend'i durdur, garson ekranında menü yenile → 30 sn sonra "Sunucu yanıt vermiyor" SnackBar (sonsuz spinner yok)
- [ ] Manuel: JWT'yi backend'de invalid yap (DB'den user sil) → ilk API çağrısında 401 → otomatik login'e yönlendirilir
- [ ] Manuel: backend 500 dönüyor → "Sunucu hatası" SnackBar, ham 500 görünmez
- [ ] Cloud_frontend geçersiz URL → error builder sayfası

**Risk:**
- Refactor scope geniş (~30-40 yer). Tek PR yerine helper-by-helper PR'lar daha güvenli.
- WS bağlantıları F10 kapsamında değil (F9'da çözüldü). Mixing yok.

**Status:** ⬜ (commit: —)

---

## SPRINT S3 — Operasyon (~2 gün)

### F12 — Spring Actuator + Docker healthcheck

- **Eksen:** Ops
- **Süre:** 3 saat
- **Bağımlılık:** —
- **Etki:** KRİTİK — container restart + monitoring zemini

**Sorun:**
- `spring-boot-starter-actuator` HİÇBİR pom.xml'de yok
- `application-prod.yml`'deki `management.endpoints.web.exposure.include: health,info` boşa düşüyor (`/actuator/health` 404)
- Healthcheck sadece `postgres`'te; edge/cloud/caddy/cloudflared'da yok → container crash'te restart tetiklenmez

**Adımlar:**
1. **Dependency** ekle (`edge/pom.xml`, `cloud/pom.xml`):
   ```xml
   <dependency>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-starter-actuator</artifactId>
   </dependency>
   <dependency>
       <groupId>io.micrometer</groupId>
       <artifactId>micrometer-registry-prometheus</artifactId>
   </dependency>
   ```
2. **`application-prod.yml`** zaten ayarlı, doğrula:
   ```yaml
   management:
     endpoints:
       web:
         exposure:
           include: health,info,metrics,prometheus
     endpoint:
       health:
         probes:
           enabled: true
         show-details: when-authorized
   ```
3. **Docker healthcheck** (`deploy/edge/docker-compose.yml`, `deploy/cloud/docker-compose.yml`):
   ```yaml
   edge:
     healthcheck:
       test: ["CMD-SHELL", "wget --quiet --spider http://localhost:8081/actuator/health || exit 1"]
       interval: 30s
       timeout: 5s
       retries: 3
       start_period: 60s
   ```
   - Cloud servisi için aynı (port 8080)
   - Caddy için `:80/health` (Caddyfile'a `/health respond 200` ekle)
   - Cloudflared için `cloudflared --version` zayıf bir varlık kontrolü
4. **`depends_on` `condition: service_healthy`** zincirini yeniden kur:
   ```yaml
   caddy:
     depends_on:
       edge:
         condition: service_healthy
   ```

**Doğrulama:**
- [ ] `curl http://localhost:8081/actuator/health` → `{"status":"UP","components":{"db":{"status":"UP"},"diskSpace":{"status":"UP"}}}`
- [ ] `docker ps` healthcheck status `healthy` görünür
- [ ] Edge backend'i kill -9 ile öldür → 90 sn içinde Docker otomatik restart eder
- [ ] `curl http://localhost:8081/actuator/prometheus` → metric'ler döner

**Risk:**
- Actuator endpoint'leri yetkilendirme gerektirir mi? `health` public, `metrics` ve `prometheus` IP kısıtlı (Caddy `@actuator` matcher) olmalı.
- Prometheus push'u F12'de yok, sadece scrape endpoint'i hazır. Gerçek Prometheus server kurulumu FAZ 3.1.

**Status:** ⬜ (commit: —)

---

### F13 — Print queue → DB-backed `print_outbox`

- **Eksen:** Ops
- **Süre:** 1 gün
- **Bağımlılık:** —
- **Etki:** KRİTİK — Edge restart'ta mutfak/kasa fişi kaybı yok

**Sorun:**
- `edge/.../print/PrintManager.java:28` → `LinkedBlockingQueue<>(500)` in-memory
- Edge restart = kuyruktaki tüm jobs **kalıcı kayıp**
- Queue dolarsa `offer() → false → sadece log.warn` (silent drop)
- Retry yok, hata kullanıcıya hiç dönmüyor

**Adımlar:**

1. **Migration** (`V25__print_outbox.sql`):
   ```sql
   CREATE TABLE print_outbox (
       id            UUID         PRIMARY KEY,
       restaurant_id UUID         NOT NULL,
       printer_id    VARCHAR(64)  NOT NULL,
       payload       BYTEA        NOT NULL,
       content_type  VARCHAR(32)  NOT NULL, -- escpos, raw, html
       status        VARCHAR(16)  NOT NULL DEFAULT 'PENDING',
       attempt_count INT          NOT NULL DEFAULT 0,
       last_error    VARCHAR(1024),
       next_attempt_at TIMESTAMPTZ,
       created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
       updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
   );
   CREATE INDEX idx_print_outbox_status_next ON print_outbox (status, next_attempt_at);
   ```

2. **Entity + Repo** (`PrintOutboxJob`, `PrintOutboxRepository`).

3. **`PrintManager` refactor**:
   - `enqueue(payload)` → `print_outbox` tablosuna INSERT (PENDING)
   - `drainScheduler` (`@Scheduled(fixedDelay = 2000)`) → `findReadyForRetry(PENDING, now)` çek, her satır için `sink.write(payload)`, başarı → `status=DONE` (veya delete), hata → `attempt_count++`, backoff (sync_outbox pattern), 10 deneme sonrası `DEAD_LETTER` + log.error
   - Eski in-memory queue tamamen kaldır

4. **Backpressure**: `print_outbox` row sayısı > 1000 olunca log.warn + UI bildirimi (F12 sonrası Cloud'a alarm)

5. **Test endpoint** (`PrintTestController`) sync mode: kuyruğa atmadan direkt sink.write, sonucu döner (kullanıcı yazıcı durumunu hemen görür)

6. **Edge admin UI**: "Yazıcı yönetimi" sekmesi (FAZ 1.6 roadmap'te zaten açık) — `print_outbox` listesi, "test yazdır" butonu, son hatalar, manuel retry

**Doğrulama:**
- [ ] Edge restart → kuyruktaki jobs DB'de kalır, yeniden başlatılır
- [ ] Yazıcı offline → 10 deneme sonra DEAD_LETTER, log.error
- [ ] Test yazdırma butonu yazıcı offline iken net hata mesajı döner

**Risk:**
- DB I/O her print için → yoğun saatte 100 sipariş/dk × 3 ticket = 300 DB write/dk. PG kolayca kaldırır.
- `BYTEA` payload boyutu: tipik fiş 1-5 KB. 1000 satırda 5 MB. OK.

**Status:** ⬜ (commit: —)

---

### F14 — Postgres backup script + systemd timer + restore drill

- **Eksen:** Ops
- **Süre:** 1 gün
- **Bağımlılık:** —
- **Etki:** KRİTİK — disaster recovery garantisi (Roadmap FAZ 1.8)

**Sorun:**
- `deploy/scripts/` içinde HİÇBİR backup script yok
- Edge & Cloud Postgres için cron / systemd timer yok
- "Felaket kurtarma" runbook'u yok
- Tek SSD bozulması = restoran verisi kaybı

**Adımlar:**

1. **`deploy/scripts/backup-edge-postgres.sh`**:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   BACKUP_DIR="/var/lib/quickserve/backups"
   STAMP=$(date -u +%Y%m%dT%H%M%SZ)
   FILE="$BACKUP_DIR/edge-$STAMP.dump"
   mkdir -p "$BACKUP_DIR"
   docker exec quickserve-edge-postgres pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB" > "$FILE"
   # Rotation: 7 daily, 4 weekly, 12 monthly
   find "$BACKUP_DIR" -name 'edge-*.dump' -mtime +30 -delete
   echo "Backup OK: $FILE ($(stat -c%s "$FILE") bytes)"
   ```

2. **`deploy/scripts/restore-edge-postgres.sh`** (parametrik: dump dosyası path):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   DUMP="$1"
   docker exec -i quickserve-edge-postgres pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists < "$DUMP"
   ```

3. **Systemd unit + timer** (`deploy/edge/systemd/`):
   - `quickserve-backup.service` (Type=oneshot, ExecStart=backup-edge-postgres.sh)
   - `quickserve-backup.timer` (OnCalendar=*-*-* 03:00:00, Persistent=true)

4. **`install.sh` güncelle**: backup script'lerini `/usr/local/bin/`'e kopyala, systemd unit'leri `/etc/systemd/system/`'e koy, `systemctl enable --now quickserve-backup.timer`

5. **Cloud-side backup** (`deploy/scripts/backup-cloud-postgres.sh`):
   - Aynı pattern + off-site upload (`rclone` ile Backblaze B2 veya AWS S3)
   - VPS'te tek SSD = single point of failure; off-site ŞART
   - Pilot için Backblaze B2 free tier (10 GB) yeterli

6. **`docs/DISASTER_RECOVERY.md`** runbook:
   - Senaryo A: Edge SSD bozuldu (yeni Pi, son backup'tan restore)
   - Senaryo B: Cloud VPS down (yeni VPS, Backblaze'den restore)
   - Senaryo C: JWT secret sızıntısı (rotation prosedürü)
   - Senaryo D: Cloudflared tunnel token sızıntısı

7. **Restore drill**: ayda 1 kez staging environment'a restore + sanity check (öncesinde test edilmeyen backup ≠ backup)

**Doğrulama:**
- [ ] `bash backup-edge-postgres.sh` → `/var/lib/quickserve/backups/edge-<timestamp>.dump` oluşur
- [ ] `systemctl status quickserve-backup.timer` → next trigger görünür
- [ ] Restore drill: backup dosyasını staging'e restore et, ürün/masa sayısı eşleşir
- [ ] Off-site upload başarılı (Backblaze'de dosya görünür)

**Risk:**
- `pg_dump` Edge yoğunken çalışırsa kısa süreli yavaşlama (Postgres MVCC sayesinde lock yok ama I/O artar). Gece 03:00 doğru saat.
- Off-site credentials VPS'te plaintext (`.env`); ileride Vault.

**Status:** ⬜ (commit: —)

---

### F15 — `logback-spring.xml` + Docker logging.options

- **Eksen:** Ops
- **Süre:** 2 saat
- **Bağımlılık:** —
- **Etki:** ÖNEMLİ — disk dolma + log kaybı + PII masking

**Sorun:**
- `logback.xml` / `logback-spring.xml` HİÇBİR yerde yok → Spring Boot default (stdout only, no rotation, no JSON)
- Docker driver `json-file` default'unda max-size yok → host disk dolar
- Hassas veri masking yok (`SuperadminBootstrapRunner` superadmin email'i log'luyor)

**Adımlar:**

1. **`edge/src/main/resources/logback-spring.xml`**:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <configuration>
       <springProperty scope="context" name="appName" source="spring.application.name"/>

       <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
           <encoder class="net.logstash.logback.encoder.LogstashEncoder">
               <fieldNames>
                   <timestamp>ts</timestamp>
                   <message>msg</message>
               </fieldNames>
           </encoder>
       </appender>

       <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
           <file>/var/log/quickserve/${appName}.log</file>
           <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
               <fileNamePattern>/var/log/quickserve/${appName}.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
               <maxFileSize>50MB</maxFileSize>
               <maxHistory>30</maxHistory>
               <totalSizeCap>2GB</totalSizeCap>
           </rollingPolicy>
           <encoder>
               <pattern>%d{ISO8601} %-5level [%thread] %logger{36} - %msg%n</pattern>
           </encoder>
       </appender>

       <root level="INFO">
           <appender-ref ref="CONSOLE"/>
           <appender-ref ref="FILE"/>
       </root>

       <logger name="com.qr" level="DEBUG"/>
       <logger name="org.springframework.security" level="WARN"/>
   </configuration>
   ```
   `cloud/src/main/resources/logback-spring.xml` aynı pattern.

2. **Dependency** (`net.logstash.logback:logstash-logback-encoder` JSON için):
   ```xml
   <dependency>
       <groupId>net.logstash.logback</groupId>
       <artifactId>logstash-logback-encoder</artifactId>
       <version>7.4</version>
   </dependency>
   ```

3. **Docker `logging.options`** (her servis için `docker-compose.yml`):
   ```yaml
   logging:
     driver: json-file
     options:
       max-size: "50m"
       max-file: "5"
   ```

4. **PII / secret masking**:
   - `SuperadminBootstrapRunner.java:129,137,167,169` → email yerine `userId` (UUID) log'la
   - `SyncSharedSecretFilter:51-54` → "ENFORCED/DISABLED" yaz, secret uzunluğu yazma
   - `CloudClientConfiguration.java:31-34` → aynı
   - `LoggingPosTerminalGateway.java:29` → full intent JSON yerine sadece `paymentId`, `method`, `principal`

5. **Volume mount** (`docker-compose.yml`):
   ```yaml
   edge:
     volumes:
       - ./logs/edge:/var/log/quickserve
   ```

**Doğrulama:**
- [ ] `docker logs quickserve-edge` JSON formatında çıktı
- [ ] `/var/log/quickserve/edge.log` dosyası oluşur, 50 MB'ı geçince rotate eder
- [ ] Email/secret loglarda görünmez
- [ ] 30 günden eski log dosyaları otomatik silinir

**Risk:**
- LogstashEncoder ek 1 MB dependency. Pi'da yer var.
- File appender Docker container içinde — volume mount unutulursa kaybolur.

**Status:** ⬜ (commit: —)

---

## Yapıldıkça Güncelleme Protokolü

1. Madde tamamlandığında:
   - Üst seviye tablodaki `⬜` → `✅`
   - Detay kart sonundaki `Status: ⬜` → `Status: ✅ (commit: <hash>)`
   - QUICKSERVE_PLAN.md `§ 9 Güncelleme günlüğü`'ne kısa satır ekle
2. Sprint tamamen bittiğinde: sprint başlığına ✅ ekle
3. Tüm 15 madde bittiğinde: `QUICKSERVE_ROADMAP.md` FAZ 1 satırlarını güncelle, bu dokümana "Pilot-Hazır ✅" mührü
4. Yeni risk tespit edilirse: F16+ olarak ek satır, sprint'lere yerleştir

---

## Kapsam Dışı Bırakılanlar (bilinçli)

Aşağıdaki bulgular fool-proof denetiminde tespit edildi ama **pilot-hazır kümeye dahil DEĞİL**. Pilot sonrası FAZ 2-3'te ele alınır:

- Soft-delete resurrection (sync, ÖNEMLİ) — pilotta nadir
- `softwareVersion` hardcoded `"0.0.1-SNAPSHOT"` ve version gating — pilotta tek versiyon
- `Payment.externalReference` UNIQUE constraint — PSP entegrasyonu olmadan moot
- WS broadcast diff (full snapshot yerine delta) — pilot ölçeğinde ölçeklenir
- `cloudflared:latest` → pinned version — KOLAY (5 dk), F12 ile birlikte yapılabilir
- Per-edge sync key (FAZ 3.9) — global key pilot için kabul edilebilir
- Multi-thread scheduler pool — Spring default 1-thread pilot için yeterli
- TZ env (`TZ: UTC`) — `LocalDateTime.now()` sweep ile birlikte yapılır, ayrı madde olmadı
- `LocalDateTime.now()` → `now(clock)` toplu sweep + ArchUnit testi — F6'da kısmi, tam sweep FAZ 3'te
- E2E test paketi (Roadmap FAZ 1.5) — fool-proof değil, test paketi; ayrı çalışma
- Yazıcı yönetim UI (Roadmap FAZ 1.6) — F13'te kısmi (test bas + outbox listesi); tam ESC/POS yönetim UI ayrı

---

## Doğrulama — "Pilot-Hazır" Checklist

Tüm 15 madde tamamlandığında aşağıdaki test senaryoları **bir oturumda** sırayla geçilmeli. Geçemezse pilot ertelenir.

- [ ] **Çift sipariş testi**: misafir QR'da "Sipariş Ver"e 5 kez ardarda bas → tek sipariş oluşur, mutfak 1 ticket basar
- [ ] **Çift ödeme testi**: kasiyer "Tahsil et" + network kesintisi + retry → tek payment yazılır, kasa açığı yok
- [ ] **Optimistic lock testi**: iki kasiyer aynı adisyona aynı saniyede ödeme alır → biri 409, kullanıcıya "yenileyin" mesajı
- [ ] **Hayalet boş masa testi**: fiscal save'i kasıtlı patlat → ödeme rollback, layout WS broadcast yayınlanmaz
- [ ] **Sync resilience testi**: Cloud'u 30 dk durdur, sipariş ver, Cloud'u aç → tüm değişiklikler sync olur, ping-pong yok
- [ ] **Sync DEAD letter testi**: bozuk payload üret, 20 deneme sonra DEAD_LETTER + log alarm
- [ ] **WS auth testi**: `ws://edge/ws/v1/kitchen/push?restaurantId=<known>` direkt deneme → 401
- [ ] **WS reconnect testi**: garson telefonu wifi'den çıkar, geri bağlan → sipariş listesi 30 sn içinde taze
- [ ] **App lifecycle testi**: app background → 5 dk → foreground → WS otomatik reconnect, state taze
- [ ] **Timeout testi**: Edge backend kapalıyken garson API çağrısı → 30 sn'de "Sunucu yanıt vermiyor" SnackBar
- [ ] **401 testi**: JWT invalid yap → otomatik login'e redirect, beyaz ekran yok
- [ ] **Healthcheck testi**: Edge backend kill → 90 sn içinde Docker restart
- [ ] **Print restart testi**: print queue dolu iken Edge restart → tüm jobs DB'den geri yüklenir
- [ ] **Backup-restore testi**: production'dan backup al, staging'e restore et → tüm tablolar eşleşir
- [ ] **Log rotation testi**: 100 MB log üret → eski dosyalar otomatik silinir, disk dolmaz

---

## Sonraki Adım (Bu plan onaylandıktan sonra)

1. Bu dokümanı oku, üstteki F-numarası listesini incele
2. Pilot tarihi belirle (örn. "T-2 hafta")
3. Sprint sırasına göre çalışmaya başla:
   - **Önce S0** (mali güvenlik) — bir kullanıcı parayı yanlış öderse ekibe felaket
   - **Sonra S1** (sync + WS güvenlik) — saha gerçekleri için
   - **Sonra S2** (UX dayanıklılık) — kullanıcı deneyimi
   - **Sonra S3** (operasyon) — pilot sırasında olmazsa olmaz
4. Her madde tamamlandıkça status'u güncelle ve QUICKSERVE_PLAN.md changelog'una ekle
