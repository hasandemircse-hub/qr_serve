package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import com.qr.common.persistence.entity.PaymentAllocationKind;
import com.qr.common.persistence.entity.PaymentMethod;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

public record ProcessPaymentRequest(
		@NotNull PaymentAllocationKind mode,
		/** FIXED_AMOUNT için zorunlu. */
		BigDecimal fixedAmount,
		@Valid List<LinePayRequest> linePayments,
		@NotNull PaymentMethod method,
		BigDecimal tipAmount,
		String externalReference,
		String printToPrinterId) {

	public record LinePayRequest(
			@NotNull UUID lineItemId,
			/** null ise satırın kalan tamamı kapatılır. */
			BigDecimal amount) {
	}
}
