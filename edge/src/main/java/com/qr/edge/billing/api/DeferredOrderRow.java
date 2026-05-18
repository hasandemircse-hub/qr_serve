package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

import com.qr.common.persistence.entity.OrderStatus;

public record DeferredOrderRow(
		UUID orderId,
		String orderNumber,
		OrderStatus status,
		UUID tableId,
		String tableLabel,
		BigDecimal remainingPrincipal,
		LocalDateTime orderedAt) {
}
