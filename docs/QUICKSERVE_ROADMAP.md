# QuickServe — Yol Haritası (Roadmap)

**Son güncelleme:** 2026-05-26
**Amaç:** Teknik MVP'den ticari lansmana ve büyümeye giden yolun fazlara bölünmüş, gerçekçi, öncelikli planı. Her iş başında bu dokümana bak, neyi yapıyorsun hangi faza ait netleştir.

İlgili belgeler:
- [QUICKSERVE_PLAN.md](./QUICKSERVE_PLAN.md) — Ürün ve mevcut kod durumu
- [DEPLOY_TEST.md](./DEPLOY_TEST.md) — İlk Cloud/Edge deploy
- [NEW_RESTAURANT_ONBOARDING.md](./NEW_RESTAURANT_ONBOARDING.md) — Restoran kurulum playbook
- [REMOTE_EDGE_TEST.md](./REMOTE_EDGE_TEST.md) — Uzaktan test Edge kurulumu

---

## 📍 Mevcut durum (2026-05-26)

| Katman | Durum | Yorum |
|---|---|---|
| **Mimari** | ✅ Çözüldü | Cloud-Edge hibrit, offline-first, Cloudflare Named Tunnel |
| **Cloud altyapı** | ✅ Canlı | `qrserve.co` VPS'te, Caddy + Let's Encrypt |
| **Edge altyapı** | ✅ Canlı | `edge.qrserve.co` Named Tunnel, sabit URL |
| **Süperadmin** | ✅ Kullanılabilir | Restoran CRUD, Edge izleme, abonelik |
| **Restoran admin** | ✅ Kullanılabilir | Menü, masa, personel, opsiyonlu ürün |
| **Personel akışı** | ✅ Kullanılabilir | Garson, mutfak, kasa, masa kapat v2 |
| **Müşteri QR akışı** | ✅ Kullanılabilir | Menü, sipariş, garson çağır, hesap iste |
| **Güvenlik** | ⚠️ MVP düzeyi | Auth var, ama Edge-Cloud sync auth eksik, rate limit yok |
| **Test** | ⚠️ Birim test var | E2E + load test eksik |
| **Operasyon** | ⚠️ Manuel | Monitoring/backup/alerting otomatize değil |
| **Yasal** | ❌ Yok | KVKK, e-fatura, sözleşme, vergi |
| **Pazarlama** | ❌ Yok | Landing page yok, demo restoran yok |

**Verdict:** Teknik MVP'nin ~%85'i tamam. Lansman için kalan %15 teknik + ticari/yasal hazırlık.

---

## 🗺 6 Fazlı Yol Haritası

### **FAZ 1 — Teknik Borç ve Sağlamlaştırma** (1-2 hafta)

Mevcut sistemde "Kısmen" olan ama kritik parçalar + birikmiş teknik borç.

| # | İş | Süre | Neden kritik |
|---|---|---|---|
| 1.1 | ~~JSON → JSONB migration + `@JdbcTypeCode(SqlTypes.JSON)`~~ ✅ | 0.5 gün | `stringtype=unspecified` hack'i kaldırıldı (V22 PG-only migration + Hibernate annotation) |
| 1.2 | Edge ↔ Cloud sync için API key auth (`/api/v1/sync/**`) | 1 gün | Şu an `permitAll` → kötü amaçlı biri Cloud'a fake hello atabilir |
| 1.3 | ~~Cloud süperadmin Edge sağlık testi (heartbeat'ten bağımsız gerçek proxy test)~~ ✅ | 0.5 gün | `POST /admin/restaurants/{id}/edge-health-check` + cloud_frontend "Sağlık testi" butonu (kalp ikonu): HTTP status, cevap süresi, edgeId/restaurantId uyumu, hata kodu. |
| 1.4 | QR PDF'ler `qrserve.co` ile yeniden üretim (eskiler nip.io) | 0.5 gün | Şu an üretilen PDF'ler eski URL kullanıyor |
| 1.5 | E2E test paketi (Playwright veya Selenium) | 2 gün | Müşteri QR → sipariş → kasa → kapanış otomatik test |
| 1.6 | Yazıcı yönetim UI (kategoriye atama, test yazdırma) | 1 gün | "Kısmen" — kod var, UI yok |
| 1.7 | `QUICKSERVE_PLAN.md` changelog güncelleme | 0.5 gün | Doküman planın gerisinde |
| 1.8 | Backup + restore script (Edge + Cloud Postgres) | 1 gün | Disaster recovery senaryolarını şimdiden çöz |

**Çıktı:** Üretime tam hazır, test edilmiş, dokumante teknik MVP.

---

### **FAZ 2 — Pilot Öncesi Özellik Tamamlama** (2-3 hafta)

Gerçek bir restoranın hayatta kalması için eksik parçalar.

| # | İş | Süre | Neden gerekli |
|---|---|---|---|
| 2.1 | Raporlama: günlük ciro, ürün satış raporları | 3 gün | Restoran sahibi ilk gün soracak |
| 2.2 | Stok yönetimi (basit envanter — "tükendi" işareti) | 2 gün | Mutfakta yok diyemediğin ürün satarsın |
| 2.3 | Mutfak KDS (Kitchen Display) ayrı ekran modu | 2 gün | Mutfakta yazıcı + ekran çalışır |
| 2.4 | İndirim / ikram yönetimi (sabit/yüzde) | 1.5 gün | Restoran realitesi: müşteriye ikram, indirim yapacaklar |
| 2.5 | Personel vardiya kapanışı + günlük Z raporu | 1.5 gün | Mali mevzuat tarafında temel zorunluluk |
| 2.6 | Müşteri/sipariş notu (alerji, "soğansız" vb.) | 1 gün | "Kısmen" — eksik özellik |
| 2.7 | E-fatura/E-adisyon interface'i (gerçek sağlayıcı bekler) | 2 gün | Şimdilik interface + mock; ileride gerçek sağlayıcı |
| 2.8 | Multi-language (TR/EN) - en azından müşteri menüsü | 2 gün | Turistik bölge restoranı için |
| 2.9 | Onboarding wizard (restoran admin ilk login'de) | 1.5 gün | "Hoş geldin, masa say kaç, menü ekle..." |

**Çıktı:** Pilot restorana götürülebilir özellik seti.

---

### **FAZ 3 — Production Hardening** (1-2 hafta, FAZ 2 ile paralel)

Saha gerçekleri için altyapı sertleştirme.

| # | İş | Süre | Neden |
|---|---|---|---|
| 3.1 | Monitoring: Prometheus + Grafana (Cloud + Edge metrikleri) | 2 gün | Sorun olunca senden önce sen duyacaksın |
| 3.2 | Alerting: UptimeRobot + e-posta/SMS | 0.5 gün | "Restoran patron 23:00'da telefon açmasın" |
| 3.3 | Log aggregation: Loki veya basit dosya rotation + s3 | 1 gün | Sorun olunca log nereye gitti? |
| 3.4 | Rate limiting (Cloud + Edge) | 1 gün | Saldırı + accidental DDoS koruması |
| 3.5 | Tailscale ile Edge fleet'e SSH | 0.5 gün | Saha gitmeden remote destek |
| 3.6 | Edge cihazlarda otomatik backup (gece 03:00) | 1 gün | Cihaz arızası = veri kaybı olmasın |
| 3.7 | CI/CD: GitHub Actions (test + build + deploy) | 2 gün | Manuel rsync sürdürülebilir değil |
| 3.8 | Süperadmin şifre policy + 2FA opsiyonu | 1 gün | Senin hesabın çalınırsa felaket |

**Çıktı:** "Telefonum kapalıyken bile çalışan" üretim sistemi.

---

### **FAZ 4 — Yasal, Ticari, Pazarlama** (1-2 hafta)

Para kazanmaya başlamak için olmazsa olmazlar.

| # | İş | Süre | Neden |
|---|---|---|---|
| 4.1 | KVKK uyum: gizlilik politikası + veri silme akışı | 2 gün | Yasal zorunluluk, müşteri verisi var |
| 4.2 | SaaS sözleşmesi (kullanım koşulları + restoran hizmet sözleşmesi) | 2 gün | Avukatla profesyonel hazırlanmalı |
| 4.3 | Pricing model: tier'lar (Basic / Pro / Premium) | 1 gün | "Aylık ne alacağım?" sorusu |
| 4.4 | Faturalama (ileride otomasyon, ilk başta manuel banka transferi) | 1 gün | İlk müşteriler için manuel ok |
| 4.5 | `qrserve.co` landing page (marketing) | 3 gün | "Bu nedir, neye yarar, ne kadar?" |
| 4.6 | Demo restoran (kendi adına seed data ile dolu örnek) | 1 gün | Potansiyel müşteriye gösterilir |
| 4.7 | Yardım merkezi / SSS | 1.5 gün | "Şifremi unuttum" gibi temel sorular |
| 4.8 | Marka kit: logo, renkler, font (Cloudflare panel + frontend) | 1 gün | Profesyonel görünüm |

**Çıktı:** "Müşteri ödeyebilir" ticari yapı.

---

### **FAZ 5 — Pilot Restoran ve İterasyon** (1 ay — KRİTİK FAZ)

**Bu faz öncekilerden daha önemli.** Gerçek sahada çalışmadan eksiklikleri göremezsin.

| # | İş | Süre |
|---|---|---|
| 5.1 | 1 pilot restoran bul (tanıdık, indirimli/ücretsiz) | 1 hafta |
| 5.2 | `NEW_RESTAURANT_ONBOARDING` playbook'u ile kurulum | 1 gün |
| 5.3 | 2 hafta yoğun saha izleme (haftada 2 ziyaret + günlük telefon) | 2 hafta |
| 5.4 | Bug fix + UX iyileştirme (hızlı iterasyon) | sürekli |
| 5.5 | Personel/sahibinden gerçek feedback toplama | sürekli |
| 5.6 | "Pilot raporu": öğrenilenler + kritik eksikler listesi | 2 gün |

**Çıktı:** Sahada validasyonu yapılmış, gerçek sorunlara karşı sertleştirilmiş ürün.

---

### **FAZ 6 — Ticari Lansman ve Ölçek** (sürekli)

5 restoran → 10 → 50 → 100. Her büyüme yeni iş.

| # | İş |
|---|---|
| 6.1 | Sales kanal (referans programı, restoran ekipmanı firma anlaşması) |
| 6.2 | Customer support (WhatsApp Business hattı, ticket sistemi) |
| 6.3 | E-fatura sağlayıcı (BizimHesap, Logo Mali, vb.) gerçek entegrasyon |
| 6.4 | Çoklu para birimi / dil (uluslararası fırsat) |
| 6.5 | Online sipariş modülü (yemek paketi gelir) |
| 6.6 | Loyalty / kampanya sistemi |
| 6.7 | Cloud-side analytics (ML ile menü önerisi, fiyat optimizasyonu) |
| 6.8 | Mobile app (sadece web SPA değil, native iOS/Android) |
| 6.9 | Fleet management: 10+ Edge için otomatik provision, OTA update |
| 6.10 | Cloud failover: müşteri QR için Cloud SPOF çözümü (akıllı fallback Edge URL'e) |

---

## ⏱ Zaman çizelgesi (sıra ile)

```
HAFTA 1-2:   FAZ 1 (Teknik borç)               ───┐
HAFTA 3-5:   FAZ 2 (Eksik özellikler)             ├─ Tam çalışan + üretime hazır ürün
HAFTA 4-5:   FAZ 3 (Hardening, paralel)        ───┘
HAFTA 6-7:   FAZ 4 (Yasal + pazarlama)            ── Para alma altyapısı
HAFTA 8-12:  FAZ 5 (Pilot restoran)               ── Validasyon
HAFTA 13+:   FAZ 6 (Lansman + büyüme)             ── Sürekli
```

**Realistik tahmin:**
- Bugünden itibaren **~3 ay sonra** ticari lansman
- **~4-5 ay sonra** ilk paralı 3-5 restoran
- **~12 ay sonra** 10-20 ödeyen restoran

---

## 🎯 Stratejik öneri — hangi sırada gitmeli

### Önerilen yol: **Erken sahaya çıkma** (FAZ 1 → FAZ 5 → diğerleri paralel)

Klasik yanılgı: "Mükemmel ürün yapayım sonra çıkarayım." Gerçek: **sahaya ne kadar erken çıkarsan o kadar erken doğru ürünü yaparsın.**

Önerilen sıra:

1. **FAZ 1**'in en kritik 4 işi (1.1, 1.2, 1.4, 1.5) — 1 hafta
2. **FAZ 3**'ün monitoring + backup (3.1, 3.6) — 3 gün
3. **FAZ 5.1**: Tanıdık restoran sahibi araştırması (pilot teklif)
4. Pilot kurulurken: **FAZ 2'nin gerekli olanları** restoranın acil ihtiyacına göre sırayla
5. Pilot çalıştıkça **FAZ 4** (yasal + pazarlama) — bu sırada "neyi satmalıyım" öğrenirsin

### Alternatif: **Klasik şelale**

Daha güvenli ama daha yavaş. FAZ 1 → FAZ 2 → FAZ 3 → FAZ 4 → FAZ 5 sırayla. 3 ay sonra pilot, 4-5 ay sonra ticari.

---

## 🚨 Kritik kararlar (henüz çözülmemiş)

Aşağıdaki sorular ileride iş yönünü değiştirebilir:

| Soru | Etki | Karar verme zamanı |
|---|---|---|
| **Pricing model**: Aylık sabit mi, sipariş/masa bazlı yüzde mi? | Gelir modeli | FAZ 4 başlamadan |
| **Edge donanımı**: Sen mi sağlayacaksın, restoran mı satın alacak? | Yatırım, gelir | FAZ 4 öncesi |
| **E-fatura sağlayıcı**: Hangisi (BizimHesap, Logo, Mikro)? | Entegrasyon eforu | FAZ 2.7 öncesi |
| **Hedef segment**: Cafe/restoran/fastfood/fine-dining? | Özellik önceliği | FAZ 5 öncesi |
| **Coğrafya**: Türkiye'nin neresi? İstanbul/Ankara/turistik? | Pazarlama + dil | FAZ 4 öncesi |
| **Açık kaynak mı kapalı kaynak mı?** | Lisans, marka, rakip | FAZ 4 öncesi |

---

## 📊 Başarı metrikleri (KPI)

Her faz sonunda ölçülecek:

| Faz | Başarı kriteri |
|---|---|
| FAZ 1 | E2E test pass rate %100, JSON tip hatası 0, hot path latency <500ms |
| FAZ 2 | Restoran admin günlük kullanım için ayrı bir araç gerektirmiyor |
| FAZ 3 | Cloud + Edge uptime >%99.5/ay, ortalama recovery <30dk |
| FAZ 4 | Bir potansiyel müşteri 5 dakikada ne yaptığını anlayabiliyor |
| FAZ 5 | Pilot restoran 2 hafta sonunda "sistemi seviyoruz" diyor |
| FAZ 6 | Aylık ödeyen restoran sayısı + müşteri başına ortalama gelir (ARPU) |

---

## 📝 Güncelleme protokolü

Bu doküman yaşayan bir doküman. Her önemli adımdan sonra güncelle:

1. Bir iş tamamlandığında: ilgili tablo satırını ~~üstü çizili~~ yap, **Not** sütununa link ekle (commit, PR, doc)
2. Yeni iş eklenirse: ilgili fazın tablosuna yeni satır
3. Faz biterse: başlığa ✅ ekle, sonraki faza geç
4. Stratejik değişiklik olursa: "Kritik kararlar" tablosunu güncelle, alttaki sıra önerisi'ni revize et

> Bu yol haritası mutlak değildir. Pilot restoran sonrası FAZ 2'nin yarısını silmen veya FAZ 6'dan yukarı çekmen gerekebilir. **Plan yapmak iyidir; plana sıkıca bağlı olmak değildir.**
