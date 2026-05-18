package com.qr.edge.admin.api;

import java.math.BigDecimal;
import java.util.UUID;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpsertProductRequest(
		@NotBlank @Size(max = 255) String name,
		@Size(max = 2000) String description,
		@NotNull @DecimalMin(value = "0.0", inclusive = true) BigDecimal price,
		@Size(max = 64) String sku,
		@DecimalMin(value = "0.0", inclusive = true) BigDecimal taxRate,
		UUID menuId) {
}
