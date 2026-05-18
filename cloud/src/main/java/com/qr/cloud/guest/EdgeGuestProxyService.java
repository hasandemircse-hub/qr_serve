package com.qr.cloud.guest;

import java.net.URI;
import java.time.Duration;
import java.util.UUID;

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
		try {
			var spec = restClient.method(method).uri(URI.create(url)).accept(MediaType.APPLICATION_JSON);
			if (requestBody != null) {
				spec = spec.contentType(MediaType.APPLICATION_JSON).body(requestBody);
			}
			return spec.retrieve().toEntity(String.class);
		} catch (RestClientResponseException ex) {
			MediaType type = ex.getResponseHeaders() != null
					? ex.getResponseHeaders().getContentType()
					: null;
			return ResponseEntity.status(ex.getStatusCode())
					.contentType(type != null ? type : MediaType.APPLICATION_JSON)
					.body(ex.getResponseBodyAsString());
		} catch (RestClientException ex) {
			throw new ResponseStatusException(
					HttpStatus.SERVICE_UNAVAILABLE,
					"Edge unreachable: " + ex.getMessage());
		}
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
