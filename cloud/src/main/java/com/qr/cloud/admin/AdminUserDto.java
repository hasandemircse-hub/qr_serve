package com.qr.cloud.admin;

import java.time.LocalDateTime;
import java.util.UUID;

import com.qr.common.security.UserRole;

public record AdminUserDto(
		UUID id,
		UUID restaurantId,
		String email,
		String displayName,
		UserRole role,
		LocalDateTime createdAt,
		LocalDateTime updatedAt) {
}
