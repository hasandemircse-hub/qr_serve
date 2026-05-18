package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.util.UUID;

import com.qr.common.persistence.entity.OrderStatus;

public record BillingRefundResponse(
		UUID paymentId,
		BigDecimal refundedPrincipal,
		BigDecimal refundedTip,
		BigDecimal remainingPrincipalAfter,
		OrderStatus orderStatus) {
}
