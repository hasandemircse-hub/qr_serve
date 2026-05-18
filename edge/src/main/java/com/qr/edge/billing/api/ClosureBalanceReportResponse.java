package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.util.List;

public record ClosureBalanceReportResponse(
		BigDecimal totalDeferredRemaining,
		List<DeferredOrderRow> deferredOrders,
		List<ClosureAuditRow> exceptionClosures) {
}
