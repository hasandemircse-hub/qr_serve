package com.qr.edge.guest.api;

import java.util.UUID;

public record GuestSessionResponse(
		UUID restaurantId,
		UUID tableId,
		String restaurantName,
		String tableLabel) {
}
