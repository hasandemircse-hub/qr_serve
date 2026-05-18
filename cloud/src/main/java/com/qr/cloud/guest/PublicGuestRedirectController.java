package com.qr.cloud.guest;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import com.qr.cloud.config.CloudQuickserveProperties;

@RestController
public class PublicGuestRedirectController {

	private final CloudQuickserveProperties properties;

	public PublicGuestRedirectController(CloudQuickserveProperties properties) {
		this.properties = properties;
	}

	/**
	 * Internet QR girişi: Cloud URL → misafir web uygulaması (Flutter hash route).
	 */
	@GetMapping("/r/{restaurantId}/t/{tableId}/{token}")
	public ResponseEntity<?> guestEntry(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		String webBase = properties.getGuest().getWebBaseUrl();
		String encodedToken = URLEncoder.encode(token, StandardCharsets.UTF_8);
		if (webBase == null || webBase.isBlank()) {
			String flutterPath = "/#/guest/qr?r=" + restaurantId
					+ "&t=" + tableId
					+ "&k=" + encodedToken
					+ "&via=cloud";
			String html = """
					<!DOCTYPE html>
					<html lang="tr">
					<head><meta charset="utf-8"><title>QuickServe Misafir</title></head>
					<body style="font-family: system-ui; max-width: 40rem; margin: 2rem auto; line-height: 1.5;">
					<h1>Misafir menü yapılandırması</h1>
					<p>Cloud QR linki çalışıyor. Misafir arayüzü için <code>quickserve.guest.web-base-url</code>
					(Flutter Web adresi) ayarlayın veya aşağıdaki yolu Flutter portunuzla açın:</p>
					<pre style="background:#f4f4f4;padding:1rem;overflow:auto;">%s</pre>
					<p>Örnek tam URL: <code>http://127.0.0.1:&lt;flutter-port&gt;%s</code></p>
					</body></html>
					""".formatted(flutterPath, flutterPath);
			return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(html);
		}
		String base = webBase.trim().replaceAll("/+$", "");
		String query = "r=" + restaurantId
				+ "&t=" + tableId
				+ "&k=" + encodedToken
				+ "&via=cloud";
		URI target = URI.create(base + "/#/guest/qr?" + query);
		return ResponseEntity.status(HttpStatus.FOUND).location(target).build();
	}
}
