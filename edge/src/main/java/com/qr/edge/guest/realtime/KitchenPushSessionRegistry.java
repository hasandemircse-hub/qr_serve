package com.qr.edge.guest.realtime;

import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;


@Component
public class KitchenPushSessionRegistry {

	private static final Logger log = LoggerFactory.getLogger(KitchenPushSessionRegistry.class);

	private final Map<UUID, Set<WebSocketSession>> sessionsByRestaurant = new ConcurrentHashMap<>();

	public void subscribe(UUID restaurantId, WebSocketSession session) {
		sessionsByRestaurant
				.computeIfAbsent(restaurantId, k -> ConcurrentHashMap.newKeySet())
				.add(session);
	}

	public void unsubscribe(WebSocketSession session) {
		Object rid = session.getAttributes().get("restaurantId");
		if (!(rid instanceof UUID uuid)) {
			return;
		}
		Set<WebSocketSession> set = sessionsByRestaurant.get(uuid);
		if (set == null) {
			return;
		}
		set.remove(session);
		if (set.isEmpty()) {
			sessionsByRestaurant.remove(uuid);
		}
	}

	public void broadcast(UUID restaurantId, String json) {
		Set<WebSocketSession> set = sessionsByRestaurant.get(restaurantId);
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
				log.warn("Kitchen WS send failed: {}", ex.getMessage());
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
