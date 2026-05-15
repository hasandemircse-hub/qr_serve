package com.qr.edge.layout;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;


@Configuration
@EnableWebSocket
public class FloorLayoutWebSocketConfig implements WebSocketConfigurer {

	private final FloorLayoutWebSocketHandler floorLayoutWebSocketHandler;

	public FloorLayoutWebSocketConfig(FloorLayoutWebSocketHandler floorLayoutWebSocketHandler) {
		this.floorLayoutWebSocketHandler = floorLayoutWebSocketHandler;
	}

	@Override
	public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
		registry.addHandler(floorLayoutWebSocketHandler, "/ws/v1/layout")
				.setAllowedOriginPatterns("*");
	}
}
