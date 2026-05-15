package com.qr.edge.qr.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record CreateQrOrderResponse(
		UUID orderId,
		String orderNumber,
		List<UUID> lineIds,
		BigDecimal grandTotal) {
}
