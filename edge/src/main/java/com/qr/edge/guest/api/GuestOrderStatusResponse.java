package com.qr.edge.guest.api;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import com.qr.common.persistence.entity.KitchenLineStatus;
import com.qr.common.persistence.entity.OrderStatus;

/**
 * Misafir QR oturumu için açık siparişler + mutfak satır durumu (REST anlığı).
 */
public record GuestOrderStatusResponse(List<Order> orders) {

	public record Order(
			UUID orderId,
			String orderNumber,
			OrderStatus status,
			LocalDateTime orderedAt,
			List<Line> lines) {
	}

	public record Line(
			UUID lineItemId,
			String productName,
			int quantity,
			KitchenLineStatus kitchenLineStatus) {
	}
}
