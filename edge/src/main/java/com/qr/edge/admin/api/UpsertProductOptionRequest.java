package com.qr.edge.admin.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpsertProductOptionRequest(
		@NotBlank @Size(max = 255) String label,
		@NotNull BigDecimal priceAdjustment,
		Integer sortIndex) {
}
