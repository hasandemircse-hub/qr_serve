package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

import com.qr.common.persistence.entity.TableClosureBalanceDisposition;
import com.qr.common.persistence.entity.TableClosurePolicy;
import com.qr.common.persistence.entity.TableClosureReasonCode;

public record ClosureAuditRow(
		UUID auditId,
		UUID orderId,
		String orderNumber,
		UUID tableId,
		String tableLabel,
		TableClosurePolicy policy,
		TableClosureReasonCode reasonCode,
		TableClosureBalanceDisposition balanceDisposition,
		BigDecimal remainingPrincipal,
		LocalDateTime closedAt,
		String note,
		String actorRole) {
}
