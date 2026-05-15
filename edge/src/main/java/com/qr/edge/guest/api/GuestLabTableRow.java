package com.qr.edge.guest.api;

import java.util.UUID;

public record GuestLabTableRow(
		UUID physicalTableId,
		String label,
		String zone,
		Integer seatCount,
		UUID qrTableId,
		String token,
		String edgeGuestPath,
		String edgeGuestUrl) {
}
