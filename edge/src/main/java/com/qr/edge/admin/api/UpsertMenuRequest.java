package com.qr.edge.admin.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpsertMenuRequest(
		@NotBlank @Size(max = 255) String name,
		@Size(max = 2000) String description,
		Boolean active) {
}
