package com.qr.edge.waiter.api;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

public record TransferTableOrdersRequest(
		@NotNull UUID sourceTableId,
		@NotNull UUID targetTableId) {
}
