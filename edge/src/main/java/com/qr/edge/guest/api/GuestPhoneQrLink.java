package com.qr.edge.guest.api;

import java.util.UUID;

public record GuestPhoneQrLink(
		String phoneScanUrl,
		String tableLabel,
		UUID restaurantId,
		UUID qrTableId,
		String token) {
}
