package com.qr.edge.qr.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record ProductOptionWizardResponse(UUID productId, List<OptionGroupPayload> groups) {

	public record OptionGroupPayload(
			UUID id,
			String name,
			String selectionType,
			int sortIndex,
			List<OptionItemPayload> options) {
	}

	public record OptionItemPayload(
			UUID id,
			String label,
			BigDecimal priceAdjustment,
			int sortIndex) {
	}
}
