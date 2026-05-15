package com.qr.edge.layout.api;

import java.util.List;

public record FloorLayoutBroadcast(
		String type,
		int schemaVersion,
		String restaurantId,
		String generatedAt,
		List<FloorLayoutPutRequest.FloorPayload> floors) {

	public static final String TYPE = "FLOOR_LAYOUT_SNAPSHOT";

	public static FloorLayoutBroadcast of(
			int schemaVersion,
			String restaurantId,
			String generatedAt,
			List<FloorLayoutPutRequest.FloorPayload> floors) {
		return new FloorLayoutBroadcast(TYPE, schemaVersion, restaurantId, generatedAt, floors);
	}
}
