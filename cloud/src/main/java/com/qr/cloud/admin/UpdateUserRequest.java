package com.qr.cloud.admin;

import com.qr.common.security.UserRole;

import jakarta.validation.constraints.Size;

/**
 * Kullanıcı güncellemesi. Tüm alanlar opsiyonel — yalnızca gönderilenler değişir.
 * Parola değiştirmek için {@code password} doldurulur; aksi halde mevcut hash korunur.
 */
public record UpdateUserRequest(
		@Size(max = 255) String displayName,
		UserRole role,
		@Size(min = 6, max = 128) String password) {
}
