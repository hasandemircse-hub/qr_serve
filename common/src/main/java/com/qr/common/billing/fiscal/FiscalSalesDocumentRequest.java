package com.qr.common.billing.fiscal;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Mali entegrasyona gönderilecek satış özeti (yasal kayıt için yeterli alanlar genişletilebilir).
 */
public record FiscalSalesDocumentRequest(
		UUID restaurantId,
		UUID orderId,
		UUID paymentId,
		FiscalDocumentKind documentKind,
		String currency,
		BigDecimal taxableBase,
		BigDecimal tipAmount,
		OffsetDateTime issuedAt,
		List<FiscalLineSnapshot> lines) {

	public record FiscalLineSnapshot(UUID lineItemId, String productName, int quantity, BigDecimal lineTotal,
			BigDecimal settledInThisPayment) {
	}
}
