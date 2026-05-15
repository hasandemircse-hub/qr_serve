package com.qr.cloud.admin;

import java.util.UUID;

import com.qr.common.security.SubscriptionStatus;

public record RestaurantSummaryDto(UUID id, String name, SubscriptionStatus subscriptionStatus) {
}
