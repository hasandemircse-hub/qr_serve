package com.qr.edge.admin.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpsertOptionGroupRequest(
		@NotBlank @Size(max = 255) String name,
		@NotNull String selectionType,
		Integer sortIndex) {
}
