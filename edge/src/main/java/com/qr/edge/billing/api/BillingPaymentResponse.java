package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.util.UUID;

import com.qr.common.persistence.entity.OrderStatus;

public record BillingPaymentResponse(
		UUID paymentId,
		BigDecimal principalAmount,
		BigDecimal tipAmount,
		BigDecimal remainingPrincipalAfter,
		OrderStatus orderStatus) {
}
