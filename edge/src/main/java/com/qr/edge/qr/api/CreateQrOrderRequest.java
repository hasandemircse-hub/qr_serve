package com.qr.edge.qr.api;

import java.util.List;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CreateQrOrderRequest(
		@NotNull UUID restaurantId,
		UUID tableId,
		String guestToken,
		@NotEmpty @Valid List<QrOrderLineRequest> lines,
		/**
		 * Sipariş kaynağı (ör. QR, WAITER). Boş veya null ise QR kabul edilir.
		 */
		String channel) {

	public CreateQrOrderRequest(UUID restaurantId, UUID tableId, String guestToken, List<QrOrderLineRequest> lines) {
		this(restaurantId, tableId, guestToken, lines, null);
	}

	public record QrOrderLineRequest(
			@NotNull UUID productId,
			@Positive int quantity,
			@NotNull JsonNode selectedOptions) {
	}
}
