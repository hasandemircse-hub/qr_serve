package com.qr.edge.info;

import java.util.UUID;

public record EdgeInfoResponse(
		UUID edgeId,
		UUID restaurantId,
		String restaurantName,
		String cloudBaseUrl,
		boolean syncEnabled,
		String activeProfiles) {
}
