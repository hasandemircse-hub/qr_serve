package com.qr.edge.guest.api;

import java.time.LocalDateTime;
import java.util.UUID;

public record GuestTokenRowDto(
		UUID id,
		String tokenPreview,
		LocalDateTime expiresAt,
		LocalDateTime createdAt,
		boolean active) {
}
