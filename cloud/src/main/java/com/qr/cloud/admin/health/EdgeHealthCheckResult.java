package com.qr.cloud.admin.health;

import java.time.LocalDateTime;
import java.util.UUID;

import com.qr.cloud.admin.EdgeConnectivityStatus;

/**
 * Cloud → Edge gerçek erişim testi sonucu.
 *
 * <p>Heartbeat (Edge'ten gelen ping) "Edge dışarı çıkabiliyor mu?" sorusunu cevaplar.
 * Bu DTO ise "Cloud (ve dolayısıyla misafir) Edge'e ulaşabiliyor mu?" sorusunu
 * cevaplar. İkisi farklı senaryolar: Cloudflare Tunnel bağlantısı koparsa
 * heartbeat hâlâ çalışır ama public URL ölmüş olur.
 */
public record EdgeHealthCheckResult(
		UUID restaurantId,
		EdgeConnectivityStatus heartbeatStatus,
		String testedUrl,
		boolean reachable,
		Integer httpStatusCode,
		Long responseTimeMillis,
		UUID reportedEdgeId,
		UUID reportedRestaurantId,
		boolean edgeIdMatches,
		boolean restaurantIdMatches,
		String errorCode,
		String errorMessage,
		LocalDateTime checkedAt) {
}
