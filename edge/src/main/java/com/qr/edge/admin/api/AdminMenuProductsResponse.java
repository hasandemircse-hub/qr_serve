package com.qr.edge.admin.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record AdminMenuProductsResponse(List<AdminMenuDto> menus) {

	public record AdminMenuDto(UUID id, String name, List<AdminProductDto> products) {
	}

	public record AdminProductDto(UUID id, String name, BigDecimal price, int optionGroupCount) {
	}
}
