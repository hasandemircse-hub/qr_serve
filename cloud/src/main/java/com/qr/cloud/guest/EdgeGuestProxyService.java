package com.qr.cloud.guest;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.qr.cloud.config.CloudQuickserveProperties;

@Service
public class EdgeGuestProxyService {

	private static final Logger log = LoggerFactory.getLogger(EdgeGuestProxyService.class);

	private final RestaurantEdgeResolver restaurantEdgeResolver;

	private final RestClient restClient;

	private final ObjectMapper objectMapper;

	public EdgeGuestProxyService(
			RestaurantEdgeResolver restaurantEdgeResolver,
			CloudQuickserveProperties properties,
			ObjectMapper objectMapper) {
		this.restaurantEdgeResolver = restaurantEdgeResolver;
		this.objectMapper = objectMapper;
		SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
		int timeoutMs = Math.max(3, properties.getGuest().getEdgeProxyTimeoutSeconds()) * 1000;
		factory.setConnectTimeout(timeoutMs);
		factory.setReadTimeout(timeoutMs);
		this.restClient = RestClient.builder().requestFactory(factory).build();
	}

	public ResponseEntity<String> forward(
			HttpMethod method,
			UUID restaurantId,
			String edgeGuestSuffix,
			String requestBody) {
		ResolvedEdge edge = requireReachableEdge(restaurantId);
		String url = normalizeBase(edge.publicEdgeUrl())
				+ "/api/v1/guest/r" + edgeGuestSuffix;
		log.debug("Edge proxy {} {}", method, url);
		try {
			var spec = restClient.method(method)
					.uri(URI.create(url))
					.accept(MediaType.APPLICATION_JSON)
					// Cloudflare gibi proxy'lerin gzip encoding eklemesini engelle:
					// SimpleClientHttpRequestFactory (HttpURLConnection) çıktı tarafında
					// auto-decompress bekliyor ama bazı Edge-tüneli zincirlerinde uyuşmazlık olabiliyor.
					.header("Accept-Encoding", "identity");
			if (requestBody != null) {
				spec = spec.contentType(MediaType.APPLICATION_JSON).body(requestBody);
			}
			ResponseEntity<byte[]> raw = spec.retrieve().toEntity(byte[].class);
			return rebuildResponse(raw);
		} catch (RestClientResponseException ex) {
			log.warn("Edge proxy {} {} returned status {} body=<{}>",
					method, url, ex.getStatusCode(), truncate(ex.getResponseBodyAsString()));
			MediaType type = ex.getResponseHeaders() != null
					? ex.getResponseHeaders().getContentType()
					: null;
			return ResponseEntity.status(ex.getStatusCode())
					.contentType(type != null ? type : MediaType.APPLICATION_JSON)
					.body(ex.getResponseBodyAsString());
		} catch (RestClientException ex) {
			log.warn("Edge proxy {} {} unreachable: {}", method, url, ex.getMessage());
			throw new ResponseStatusException(
					HttpStatus.SERVICE_UNAVAILABLE,
					"Edge unreachable: " + ex.getMessage());
		} catch (Exception ex) {
			log.error("Edge proxy {} {} unexpected failure", method, url, ex);
			throw new ResponseStatusException(
					HttpStatus.BAD_GATEWAY,
					"Edge proxy failure: " + ex.getClass().getSimpleName());
		}
	}

	/**
	 * Edge'den gelen yanıtı temiz bir ResponseEntity'e dönüştür.
	 * Hop-by-hop header'lar (Transfer-Encoding, Content-Length, Connection) elenir;
	 * gövde UTF-8 String olarak yeniden serileştirilir, böylece Servlet container'ın
	 * yanıtı yazarken patlama riski azalır.
	 */
	private static ResponseEntity<String> rebuildResponse(ResponseEntity<byte[]> raw) {
		byte[] body = raw.getBody();
		String text = body != null ? new String(body, StandardCharsets.UTF_8) : "";
		MediaType type = raw.getHeaders().getContentType();
		return ResponseEntity.status(raw.getStatusCode())
				.contentType(type != null ? type : MediaType.APPLICATION_JSON)
				.body(text);
	}

	private static String truncate(String s) {
		if (s == null) return "";
		return s.length() > 240 ? s.substring(0, 240) + "…" : s;
	}

	public ResponseEntity<String> forwardSession(UUID restaurantId, String edgeGuestSuffix) {
		ResolvedEdge edge = requireReachableEdge(restaurantId);
		ResponseEntity<String> upstream = forward(HttpMethod.GET, restaurantId, edgeGuestSuffix, null);
		if (!upstream.getStatusCode().is2xxSuccessful() || upstream.getBody() == null) {
			return upstream;
		}
		try {
			JsonNode root = objectMapper.readTree(upstream.getBody());
			if (root instanceof ObjectNode obj) {
				obj.put("edgeRealtimeBaseUrl", normalizeBase(edge.publicEdgeUrl()));
			}
			return ResponseEntity.status(upstream.getStatusCode())
					.contentType(MediaType.APPLICATION_JSON)
					.body(objectMapper.writeValueAsString(root));
		} catch (Exception ex) {
			throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Invalid session response from edge");
		}
	}

	private ResolvedEdge requireReachableEdge(UUID restaurantId) {
		ResolvedEdge edge = restaurantEdgeResolver.resolve(restaurantId);
		if (!edge.isReachable()) {
			String detail = edge.connectivityStatus() != null
					? edge.connectivityStatus().name()
					: "UNKNOWN";
			throw new ResponseStatusException(
					HttpStatus.SERVICE_UNAVAILABLE,
					"Restaurant edge is not available: " + detail);
		}
		return edge;
	}

	private static String normalizeBase(String base) {
		if (base == null || base.isBlank()) {
			return "";
		}
		String s = base.trim();
		while (s.endsWith("/")) {
			s = s.substring(0, s.length() - 1);
		}
		return s;
	}
}
