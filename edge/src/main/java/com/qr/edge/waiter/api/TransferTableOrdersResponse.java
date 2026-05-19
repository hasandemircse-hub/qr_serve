package com.qr.edge.waiter.api;

import java.util.List;
import java.util.UUID;

public record TransferTableOrdersResponse(
		UUID sourceTableId,
		String sourceTableLabel,
		UUID targetTableId,
		String targetTableLabel,
		List<UUID> transferredOrderIds,
		int transferredCount) {
}
