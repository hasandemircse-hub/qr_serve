package com.qr.edge.cashier.api;

import java.math.BigDecimal;
import java.util.UUID;

import com.qr.common.persistence.entity.OrderStatus;

public record CashierOpenOrderRow(
		UUID orderId,
		String orderNumber,
		UUID tableId,
		String tableLabel,
		OrderStatus status,
		BigDecimal orderTotal,
		BigDecimal remainingPrincipal,
		int lineCount) {
}
