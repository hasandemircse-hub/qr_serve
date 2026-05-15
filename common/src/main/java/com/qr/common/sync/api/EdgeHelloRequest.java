package com.qr.common.sync.api;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

public record EdgeHelloRequest(
		@NotNull UUID edgeId,
		@NotNull UUID restaurantId,
		String publicEdgeUrl,
		String softwareVersion) {
}
