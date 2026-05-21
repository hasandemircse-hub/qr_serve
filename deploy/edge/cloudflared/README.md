# Cloudflare Tunnel kurulum (Edge)

Edge makinesi NAT arkasında bile olsa Cloud sunucusu ve internetteki misafir,
public bir hostname üzerinden Edge'e ulaşabilsin diye Cloudflare Tunnel kullanıyoruz.

## 1. Cloudflare'da tunnel oluştur

Cloudflare Zero Trust paneli → Networks → Tunnels → **Create a tunnel**:

1. **Cloudflared** seçeneğini seç.
2. Tunnel adı ver (ör. `quickserve-edge-r1`).
3. Çıkan ekranda **Docker** sekmesini seç ve **token**'ı kopyala
   (içinde `eyJ...` ile başlayan uzun string). Bu değeri `.env` dosyasında
   `CLOUDFLARED_TUNNEL_TOKEN` olarak gir.

## 2. Public hostname tanımla

Aynı sayfada **Public Hostname** sekmesi:

| Alan | Değer |
|------|--------|
| Subdomain | edge-r1 |
| Domain | tunnel.example.com (sahip olduğun bir Cloudflare domain) |
| Service Type | HTTP |
| URL | edge:8081 |

`Service URL`'de Docker servis adı (`edge:8081`) gönderilir; cloudflared
sidecar konteyneri compose ağında olduğu için bu hostname'i çözebilir.

> WebSocket için ek ayar gerekmez; Cloudflare Tunnel otomatik destekler.

## 3. .env'de URL'leri eşle

Public hostname `edge-r1.tunnel.example.com` ise Edge `.env` dosyasında:

```env
QUICKSERVE_PUBLIC_EDGE_URL=https://edge-r1.tunnel.example.com
```

Bu URL, Edge'in Cloud'a gönderdiği `hello` payload'una yazılır;
Cloud misafir BFF bu adres üzerinden Edge guest API ve WS'e ulaşır.

## 4. Doğrulama

Edge çalışırken Cloud sunucusundan:

```bash
curl -s https://edge-r1.tunnel.example.com/api/v1/edge/info
```

200 dönmeli. Cloud süperadmin paneli ayrıca restoranı `ONLINE` göstermelidir.
