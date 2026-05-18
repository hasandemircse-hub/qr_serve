package com.qr.edge.guest.realtime;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;


@Configuration
public class GuestQrWebSocketConfig implements WebSocketConfigurer {

	private final GuestMenuWebSocketHandler guestMenuWebSocketHandler;

	private final KitchenPushWebSocketHandler kitchenPushWebSocketHandler;

	private final WaiterPushWebSocketHandler waiterPushWebSocketHandler;

	private final CashierPushWebSocketHandler cashierPushWebSocketHandler;

	public GuestQrWebSocketConfig(
			GuestMenuWebSocketHandler guestMenuWebSocketHandler,
			KitchenPushWebSocketHandler kitchenPushWebSocketHandler,
			WaiterPushWebSocketHandler waiterPushWebSocketHandler,
			CashierPushWebSocketHandler cashierPushWebSocketHandler) {
		this.guestMenuWebSocketHandler = guestMenuWebSocketHandler;
		this.kitchenPushWebSocketHandler = kitchenPushWebSocketHandler;
		this.waiterPushWebSocketHandler = waiterPushWebSocketHandler;
		this.cashierPushWebSocketHandler = cashierPushWebSocketHandler;
	}

	@Override
	public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
		registry.addHandler(guestMenuWebSocketHandler, "/ws/v1/guest").setAllowedOriginPatterns("*");
		registry.addHandler(kitchenPushWebSocketHandler, "/ws/v1/kitchen/push").setAllowedOriginPatterns("*");
		registry.addHandler(waiterPushWebSocketHandler, "/ws/v1/waiter/push").setAllowedOriginPatterns("*");
		registry.addHandler(cashierPushWebSocketHandler, "/ws/v1/cashier/push").setAllowedOriginPatterns("*");
	}
}
