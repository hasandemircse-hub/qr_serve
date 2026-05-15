package com.qr.edge.guest.realtime;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;


@Component
public class GuestMenuSessionRegistry {

	private static final Logger log = LoggerFactory.getLogger(GuestMenuSessionRegistry.class);

	private final Map<String, Set<WebSocketSession>> sessionsByGuestKey = new ConcurrentHashMap<>();

	public static String guestKey(String restaurantId, String tableId, String token) {
		return restaurantId + "|" + tableId + "|" + token;
	}

	public void subscribe(String guestKey, WebSocketSession session) {
		sessionsByGuestKey
				.computeIfAbsent(guestKey, k -> ConcurrentHashMap.newKeySet())
				.add(session);
	}

	public void unsubscribe(WebSocketSession session) {
		Object key = session.getAttributes().get("guestKey");
		if (!(key instanceof String gk)) {
			return;
		}
		Set<WebSocketSession> set = sessionsByGuestKey.get(gk);
		if (set == null) {
			return;
		}
		set.remove(session);
		if (set.isEmpty()) {
			sessionsByGuestKey.remove(gk);
		}
	}

	public void broadcastByToken(String restaurantId, String tableId, String token, String json) {
		String gk = guestKey(restaurantId, tableId, token);
		Set<WebSocketSession> set = sessionsByGuestKey.get(gk);
		if (set == null || set.isEmpty()) {
			return;
		}
		TextMessage message = new TextMessage(json);
		for (WebSocketSession session : Set.copyOf(set)) {
			if (!session.isOpen()) {
				continue;
			}
			try {
				synchronized (session) {
					session.sendMessage(message);
				}
			} catch (Exception ex) {
				log.warn("Guest WS send failed: {}", ex.getMessage());
				try {
					session.close();
				} catch (Exception ignored) {
					// ignore
				}
				unsubscribe(session);
			}
		}
	}
}
