package com.qr.edge.guest.realtime;

import java.net.URI;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.springframework.web.util.UriComponentsBuilder;


@Component
public class KitchenPushWebSocketHandler extends TextWebSocketHandler {

	private final KitchenPushSessionRegistry registry;

	public KitchenPushWebSocketHandler(KitchenPushSessionRegistry registry) {
		this.registry = registry;
	}

	@Override
	public void afterConnectionEstablished(WebSocketSession session) throws Exception {
		try {
			UUID rid = parseRestaurantId(session.getUri());
			session.getAttributes().put("restaurantId", rid);
			registry.subscribe(rid, session);
		} catch (IllegalArgumentException ex) {
			session.close(CloseStatus.BAD_DATA.withReason(ex.getMessage()));
		}
	}

	@Override
	public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
		registry.unsubscribe(session);
	}

	@Override
	public void handleTransportError(WebSocketSession session, Throwable exception) {
		registry.unsubscribe(session);
	}

	private static UUID parseRestaurantId(URI uri) {
		if (uri == null || uri.getQuery() == null) {
			throw new IllegalArgumentException("Missing query: restaurantId");
		}
		Map<String, String> params = UriComponentsBuilder.fromUri(uri).build().getQueryParams().toSingleValueMap();
		String raw = params.get("restaurantId");
		if (raw == null || raw.isBlank()) {
			throw new IllegalArgumentException("Missing restaurantId query parameter");
		}
		return UUID.fromString(raw.trim());
	}
}
