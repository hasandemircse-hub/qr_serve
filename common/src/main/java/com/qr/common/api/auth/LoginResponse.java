package com.qr.common.api.auth;

import java.util.UUID;

import com.qr.common.security.UserRole;

public record LoginResponse(
		String accessToken,
		String tokenType,
		long expiresInSeconds,
		UserRole role,
		UUID restaurantId,
		String displayName,
		String email) {
}
