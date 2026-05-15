package com.qr.edge.kitchen.api;

import java.time.LocalDateTime;
import java.util.UUID;

import com.qr.common.persistence.entity.KitchenLineStatus;

public record KitchenQueueLineRow(
		UUID orderId,
		String orderNumber,
		String tableLabel,
		String orderChannel,
		LocalDateTime orderedAt,
		UUID lineId,
		String productName,
		int quantity,
		KitchenLineStatus kitchenLineStatus) {
}
