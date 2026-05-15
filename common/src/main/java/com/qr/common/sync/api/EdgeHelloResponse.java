package com.qr.common.sync.api;

import java.time.LocalDateTime;
import java.util.UUID;

public record EdgeHelloResponse(
		boolean acknowledged,
		UUID edgeId,
		LocalDateTime serverTime,
		String message) {
}
