package com.qr.cloud.admin;

import java.time.LocalDateTime;
import java.util.UUID;

import com.qr.common.security.SubscriptionStatus;

public record AdminRestaurantOverviewDto(
		UUID id,
		String name,
		SubscriptionStatus subscriptionStatus,
		UUID edgeId,
		String publicEdgeUrl,
		LocalDateTime lastHelloAt,
		LocalDateTime lastAcknowledgedUpdatedAt,
		EdgeConnectivityStatus edgeStatus) {
}
