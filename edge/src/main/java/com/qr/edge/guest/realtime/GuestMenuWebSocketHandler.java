package com.qr.edge.guest.realtime;

import java.net.URI;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.springframework.web.util.UriComponentsBuilder;

import com.qr.common.persistence.repository.TableGuestTokenRepository;


@Component
public class GuestMenuWebSocketHandler extends TextWebSocketHandler {

	private final Clock clock;

	private final TableGuestTokenRepository tableGuestTokenRepository;

	private final GuestMenuSessionRegistry guestMenuSessionRegistry;

	public GuestMenuWebSocketHandler(
			Clock clock,
			TableGuestTokenRepository tableGuestTokenRepository,
			GuestMenuSessionRegistry guestMenuSessionRegistry) {
		this.clock = clock;
		this.tableGuestTokenRepository = tableGuestTokenRepository;
		this.guestMenuSessionRegistry = guestMenuSessionRegistry;
	}

	@Override
	public void afterConnectionEstablished(WebSocketSession session) throws Exception {
		try {
			URI uri = session.getUri();
			if (uri == null || uri.getQuery() == null) {
				session.close(CloseStatus.BAD_DATA.withReason("Missing query string"));
				return;
			}
			Map<String, String> params = UriComponentsBuilder.fromUri(uri).build().getQueryParams().toSingleValueMap();
			UUID rid = UUID.fromString(require(params, "restaurantId"));
			UUID tid = UUID.fromString(require(params, "tableId"));
			String token = require(params, "token");
			LocalDateTime now = LocalDateTime.now(clock);
			var valid = tableGuestTokenRepository
					.findByRestaurantIdAndTableIdAndTokenAndIsDeletedFalseAndExpiresAtAfter(rid, tid, token, now);
			if (valid.isEmpty()) {
				session.close(CloseStatus.BAD_DATA.withReason("Invalid or expired guest token"));
				return;
			}
			String guestKey = GuestMenuSessionRegistry.guestKey(rid.toString(), tid.toString(), token);
			session.getAttributes().put("guestKey", guestKey);
			session.getAttributes().put("restaurantId", rid);
			session.getAttributes().put("tableId", tid);
			session.getAttributes().put("token", token);
			guestMenuSessionRegistry.subscribe(guestKey, session);
			session.sendMessage(new TextMessage("{\"type\":\"CONNECTED\",\"channel\":\"guest\"}"));
		} catch (IllegalArgumentException ex) {
			session.close(CloseStatus.BAD_DATA.withReason(ex.getMessage()));
		}
	}

	@Override
	public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
		guestMenuSessionRegistry.unsubscribe(session);
	}

	@Override
	public void handleTransportError(WebSocketSession session, Throwable exception) {
		guestMenuSessionRegistry.unsubscribe(session);
	}

	private static String require(Map<String, String> params, String key) {
		String v = params.get(key);
		if (v == null || v.isBlank()) {
			throw new IllegalArgumentException("Missing query: " + key);
		}
		return v.trim();
	}
}
