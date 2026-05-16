package com.qr.edge.admin.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record AdminProductOptionGroupsResponse(
		UUID productId,
		String productName,
		List<AdminOptionGroupDto> groups) {

	public record AdminOptionGroupDto(
			UUID id,
			String name,
			String selectionType,
			int sortIndex,
			List<AdminOptionItemDto> options) {
	}

	public record AdminOptionItemDto(UUID id, String label, BigDecimal priceAdjustment, int sortIndex) {
	}
}
