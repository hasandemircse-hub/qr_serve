package com.qr.edge.admin.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record AdminMenuTreeResponse(List<AdminMenuDetailDto> menus) {

	public record AdminMenuDetailDto(
			UUID id,
			String name,
			String description,
			boolean active,
			List<AdminProductDetailDto> products) {
	}

	public record AdminProductDetailDto(
			UUID id,
			String name,
			String description,
			BigDecimal price,
			String sku,
			BigDecimal taxRate) {
	}
}
