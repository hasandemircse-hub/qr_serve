package com.qr.edge.print.billing;

import java.math.BigDecimal;
import java.util.List;

public record AdisyonSlipModel(
		String restaurantName,
		String orderNumber,
		String tableLabel,
		List<LineEntry> lines,
		BigDecimal orderTotal,
		BigDecimal principalThisPayment,
		BigDecimal tipAmount,
		BigDecimal remainingAfterPayment,
		String paymentMethod,
		String footerNote) {

	public record LineEntry(String title, int quantity, BigDecimal lineTotal, BigDecimal settledByThisPayment) {
	}
}
