package com.qr.cloud.admin.health;

import java.net.URI;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.cloud.admin.EdgeConnectivityStatus;
import com.qr.common.persistence.entity.EdgeSyncCheckpoint;
import com.qr.common.persistence.repository.EdgeSyncCheckpointRepository;
import com.qr.common.persistence.repository.RestaurantRepository;

/**
 * Cloud → Edge'e gerçek bir HTTP isteği gönderip Edge'in public URL üzerinden
 * erişilebilir olduğunu doğrular. Heartbeat'in tersine, Cloud'un ve dolayısıyla
 * misafir QR akışının Edge'i gerçekten "görebildiğini" kanıtlar.
 *
 * <p>Test edilen endpoint: <code>GET {publicEdgeUrl}/api/v1/edge/info</code>
 * (Edge'de <code>permitAll</code> — kimlik doğrulaması gerekmez).
 *
 * <p>Cevap içinde dönen <code>edgeId</code> ve <code>restaurantId</code>
 * Cloud'un beklediği değerlerle karşılaştırılır; uyumsuzluk varsa
 * (örn. başkası tunnel'ı ele geçirmiş) bu durum sonuçta görünür.
 */
@Service
@Profile("!test")
public class EdgeHealthCheckService {

	private static final Logger log = LoggerFactory.getLogger(EdgeHealthCheckService.class);

	private static final int TIMEOUT_MS = 5_000;

	private final Clock clock;

	private final RestaurantRepository restaurantRepository;

	private final EdgeSyncCheckpointRepository checkpointRepository;

	private final ObjectMapper objectMapper;

	private final Duration onlineThreshold;

	private final RestClient restClient;

	public EdgeHealthCheckService(
			Clock clock,
			RestaurantRepository restaurantRepository,
			EdgeSyncCheckpointRepository checkpointRepository,
			ObjectMapper objectMapper,
			@Value("${quickserve.admin.edge-online-threshold-seconds:180}") long onlineThresholdSeconds) {
		this.clock = clock;
		this.restaurantRepository = restaurantRepository;
		this.checkpointRepository = checkpointRepository;
		this.objectMapper = objectMapper;
		this.onlineThreshold = Duration.ofSeconds(Math.max(30, onlineThresholdSeconds));
		SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
		factory.setConnectTimeout(TIMEOUT_MS);
		factory.setReadTimeout(TIMEOUT_MS);
		this.restClient = RestClient.builder().requestFactory(factory).build();
	}

	@Transactional(readOnly = true)
	public EdgeHealthCheckResult check(UUID restaurantId) {
		LocalDateTime now = LocalDateTime.now(clock);

		// Subscription durumu (FROZEN dahil) önemli değil — admin her halükarda
		// tüneli test edebilmeli; ama silinmiş restoran 404 olmalı.
		restaurantRepository.findById(restaurantId)
				.filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found"));

		EdgeSyncCheckpoint checkpoint = checkpointRepository
				.findFirstByRegisteredRestaurantIdOrderByLastHelloAtDesc(restaurantId)
				.orElse(null);

		EdgeConnectivityStatus heartbeatStatus = resolveHeartbeatStatus(checkpoint, now);
		UUID expectedEdgeId = checkpoint != null ? checkpoint.getEdgeId() : null;
		String publicEdgeUrl = checkpoint != null ? checkpoint.getPublicEdgeUrl() : null;

		if (publicEdgeUrl == null || publicEdgeUrl.isBlank()) {
			return new EdgeHealthCheckResult(
					restaurantId,
					heartbeatStatus,
					null,
					false,
					null,
					null,
					null,
					null,
					false,
					false,
					"NO_PUBLIC_URL",
					"Edge bu restoran için public URL bildirmemiş (henüz hello atmamış).",
					now);
		}

		String url = normalizeBase(publicEdgeUrl) + "/api/v1/edge/info";
		long started = System.nanoTime();

		try {
			ResponseEntity<String> response = restClient.get()
					.uri(URI.create(url))
					.accept(MediaType.APPLICATION_JSON)
					.header("Accept-Encoding", "identity")
					.retrieve()
					.toEntity(String.class);

			long elapsedMs = (System.nanoTime() - started) / 1_000_000L;
			return parseSuccess(restaurantId, expectedEdgeId, heartbeatStatus, url, response, elapsedMs, now);

		} catch (RestClientResponseException ex) {
			long elapsedMs = (System.nanoTime() - started) / 1_000_000L;
			HttpStatusCode status = ex.getStatusCode();
			log.info("Edge health check {} returned HTTP {}", url, status.value());
			return new EdgeHealthCheckResult(
					restaurantId,
					heartbeatStatus,
					url,
					false,
					status.value(),
					elapsedMs,
					null,
					null,
					false,
					false,
					"HTTP_" + status.value(),
					"Edge HTTP " + status.value() + " döndü.",
					now);

		} catch (Exception ex) {
			long elapsedMs = (System.nanoTime() - started) / 1_000_000L;
			log.info("Edge health check {} failed: {}", url, ex.getMessage());
			return new EdgeHealthCheckResult(
					restaurantId,
					heartbeatStatus,
					url,
					false,
					null,
					elapsedMs,
					null,
					null,
					false,
					false,
					classifyError(ex),
					ex.getMessage() != null ? ex.getMessage() : ex.getClass().getSimpleName(),
					now);
		}
	}

	private EdgeHealthCheckResult parseSuccess(
			UUID restaurantId,
			UUID expectedEdgeId,
			EdgeConnectivityStatus heartbeatStatus,
			String url,
			ResponseEntity<String> response,
			long elapsedMs,
			LocalDateTime now) {

		boolean is2xx = response.getStatusCode().is2xxSuccessful();
		String body = response.getBody();

		UUID reportedEdgeId = null;
		UUID reportedRestaurantId = null;
		String errorMessage = null;
		String errorCode = null;

		if (is2xx && body != null && !body.isBlank()) {
			try {
				JsonNode root = objectMapper.readTree(body);
				reportedEdgeId = readUuid(root, "edgeId");
				reportedRestaurantId = readUuid(root, "restaurantId");
			} catch (Exception ex) {
				errorCode = "INVALID_JSON";
				errorMessage = "Edge cevabı JSON olarak parse edilemedi: " + ex.getMessage();
			}
		}

		boolean edgeIdMatches = reportedEdgeId != null && expectedEdgeId != null
				&& reportedEdgeId.equals(expectedEdgeId);
		boolean restaurantIdMatches = reportedRestaurantId != null
				&& reportedRestaurantId.equals(restaurantId);

		if (is2xx && errorCode == null) {
			if (reportedEdgeId == null || reportedRestaurantId == null) {
				errorCode = "MISSING_IDENTITY";
				errorMessage = "Edge cevabında edgeId/restaurantId alanları yok.";
			} else if (!edgeIdMatches) {
				errorCode = "EDGE_ID_MISMATCH";
				errorMessage = String.format(
						"Beklenen edgeId %s, gelen %s. Tunnel başka bir Edge'e bağlanmış olabilir.",
						expectedEdgeId, reportedEdgeId);
			} else if (!restaurantIdMatches) {
				errorCode = "RESTAURANT_ID_MISMATCH";
				errorMessage = String.format(
						"Beklenen restaurantId %s, gelen %s.",
						restaurantId, reportedRestaurantId);
			}
		}

		boolean reachable = is2xx && errorCode == null;

		return new EdgeHealthCheckResult(
				restaurantId,
				heartbeatStatus,
				url,
				reachable,
				response.getStatusCode().value(),
				elapsedMs,
				reportedEdgeId,
				reportedRestaurantId,
				edgeIdMatches,
				restaurantIdMatches,
				errorCode,
				errorMessage,
				now);
	}

	private EdgeConnectivityStatus resolveHeartbeatStatus(EdgeSyncCheckpoint checkpoint, LocalDateTime now) {
		if (checkpoint == null || checkpoint.getLastHelloAt() == null) {
			return EdgeConnectivityStatus.NEVER_SEEN;
		}
		if (!checkpoint.getLastHelloAt().isBefore(now.minus(onlineThreshold))) {
			return EdgeConnectivityStatus.ONLINE;
		}
		return EdgeConnectivityStatus.OFFLINE;
	}

	private static UUID readUuid(JsonNode root, String field) {
		JsonNode node = root.get(field);
		if (node == null || node.isNull()) {
			return null;
		}
		try {
			return UUID.fromString(node.asText());
		} catch (IllegalArgumentException ex) {
			return null;
		}
	}

	private static String classifyError(Exception ex) {
		String name = ex.getClass().getSimpleName();
		if (name.contains("Timeout")) return "TIMEOUT";
		if (name.contains("UnknownHost")) return "DNS_FAIL";
		if (name.contains("Connect")) return "CONNECTION_REFUSED";
		if (name.contains("Ssl") || name.contains("Certificate")) return "TLS_FAIL";
		return "UNREACHABLE";
	}

	private static String normalizeBase(String base) {
		if (base == null || base.isBlank()) return "";
		String s = base.trim();
		while (s.endsWith("/")) {
			s = s.substring(0, s.length() - 1);
		}
		return s;
	}
}
