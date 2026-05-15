package com.qr.common.sync.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.qr.common.sync.SyncEntityType;

import jakarta.validation.constraints.NotNull;

public record SyncEntityEnvelope(
		@NotNull SyncEntityType entityType,
		@NotNull JsonNode payload) {
}
