package com.qr.edge.layout;

import java.net.URI;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.springframework.web.util.UriComponentsBuilder;


@Component
public class FloorLayoutWebSocketHandler extends TextWebSocketHandler {

	private final LayoutSessionRegistry layoutSessionRegistry;

	private final FloorLayoutService floorLayoutService;

	public FloorLayoutWebSocketHandler(LayoutSessionRegistry layoutSessionRegistry, FloorLayoutService floorLayoutService) {
		this.layoutSessionRegistry = layoutSessionRegistry;
		this.floorLayoutService = floorLayoutService;
	}

	@Override
	public void afterConnectionEstablished(WebSocketSession session) throws Exception {
		try {
			UUID restaurantId = extractRestaurantId(session.getUri());
			session.getAttributes().put("restaurantId", restaurantId);
			floorLayoutService.sendSnapshotToSession(restaurantId, session);
			layoutSessionRegistry.subscribe(restaurantId, session);
		} catch (org.springframework.web.server.ResponseStatusException ex) {
			session.close(CloseStatus.BAD_DATA.withReason(ex.getReason()));
		} catch (IllegalArgumentException ex) {
			session.close(CloseStatus.BAD_DATA.withReason(ex.getMessage()));
		}
	}

	@Override
	public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
		layoutSessionRegistry.unsubscribe(session);
	}

	@Override
	public void handleTransportError(WebSocketSession session, Throwable exception) {
		layoutSessionRegistry.unsubscribe(session);
	}

	@Override
	protected void handleTextMessage(WebSocketSession session, TextMessage message) {
		// Terminals may send pings later; ignore for now.
	}

	private static UUID extractRestaurantId(URI uri) {
		if (uri == null || uri.getQuery() == null) {
			throw new IllegalArgumentException("Missing query: restaurantId");
		}
		Map<String, String> params = UriComponentsBuilder.fromUri(uri).build().getQueryParams().toSingleValueMap();
		String raw = params.get("restaurantId");
		if (raw == null || raw.isBlank()) {
			throw new IllegalArgumentException("Missing restaurantId query parameter");
		}
		return UUID.fromString(raw);
	}
}
