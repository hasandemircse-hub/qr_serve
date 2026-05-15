package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.PaymentAllocationKind;
import com.qr.common.persistence.entity.PaymentMethod;

public record BillingSummaryResponse(
		UUID orderId,
		String orderNumber,
		OrderStatus status,
		BigDecimal orderTotal,
		BigDecimal principalPaid,
		BigDecimal remainingPrincipal,
		List<LineSummary> lines,
		List<PaymentSummary> payments) {

	public record LineSummary(
			UUID lineItemId,
			String productName,
			int quantity,
			BigDecimal lineTotal,
			BigDecimal settledAmount,
			BigDecimal remainingOnLine) {
	}

	public record PaymentSummary(
			UUID paymentId,
			BigDecimal principalAmount,
			BigDecimal tipAmount,
			PaymentMethod method,
			PaymentAllocationKind allocationKind,
			LocalDateTime paidAt) {
	}
}
