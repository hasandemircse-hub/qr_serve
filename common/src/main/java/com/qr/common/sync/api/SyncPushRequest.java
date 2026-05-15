package com.qr.common.sync.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

public record SyncPushRequest(
		@NotNull UUID batchId,
		@NotNull UUID edgeId,
		@NotEmpty @Valid List<SyncEntityEnvelope> items) {
}
