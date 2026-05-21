package com.qr.cloud.admin;

import com.qr.common.security.UserRole;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateUserRequest(
		@Email @NotBlank @Size(max = 320) String email,
		@NotBlank @Size(min = 6, max = 128) String password,
		@Size(max = 255) String displayName,
		@NotNull UserRole role) {
}
