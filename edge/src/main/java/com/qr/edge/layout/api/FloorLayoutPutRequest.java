package com.qr.edge.layout.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

public record FloorLayoutPutRequest(
		@NotNull Integer schemaVersion,
		@NotNull UUID restaurantId,
		@NotEmpty @Valid List<FloorPayload> floors) {

	public record FloorPayload(
			@NotNull Integer floorIndex,
			@NotNull String label,
			@NotNull @Valid List<TableLayoutPayload> tables) {
	}

	public record TableLayoutPayload(
			@NotNull UUID tableId,
			@NotNull String label,
			@NotNull String shape,
			@NotNull Double x,
			@NotNull Double y,
			@NotNull Double width,
			@NotNull Double height,
			@NotNull Integer floorIndex,
			UUID groupId,
			@NotNull String availabilityStatus,
			Integer seatCount,
			String zone,
			Double rotation) {
	}
}
