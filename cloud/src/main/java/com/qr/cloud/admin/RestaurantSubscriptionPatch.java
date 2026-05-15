package com.qr.cloud.admin;

import com.qr.common.security.SubscriptionStatus;

import jakarta.validation.constraints.NotNull;

public record RestaurantSubscriptionPatch(@NotNull SubscriptionStatus subscriptionStatus) {
}
