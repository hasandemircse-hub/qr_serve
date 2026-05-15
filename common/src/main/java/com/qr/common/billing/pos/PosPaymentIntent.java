package com.qr.common.billing.pos;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

/**
 * POS / ödeme terminali ile JSON tabanlı haberleşme için taşınan niyet nesnesi.
 */
public record PosPaymentIntent(
		UUID restaurantId,
		UUID orderId,
		UUID paymentId,
		String paymentMethod,
		BigDecimal principalAmount,
		BigDecimal tipAmount,
		String allocationKind,
		Map<String, Object> extensions) {
}
