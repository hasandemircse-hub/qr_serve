package com.qr.cloud.admin;

import com.qr.common.security.SubscriptionStatus;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateRestaurantRequest(
		@NotBlank @Size(max = 255) String name,
		@Size(max = 255) String legalName,
		@Size(max = 32) String taxId,
		SubscriptionStatus subscriptionStatus) {
}
