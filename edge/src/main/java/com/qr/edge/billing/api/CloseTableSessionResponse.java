package com.qr.edge.billing.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import com.qr.common.persistence.entity.TableClosurePolicy;

public record CloseTableSessionResponse(
		UUID tableId,
		String tableLabel,
		List<UUID> closedOrderIds,
		boolean tableReleased,
		TableClosurePolicy policy,
		BigDecimal totalRemainingPrincipal,
		List<UUID> auditLogIds) {
}
