package com.qr.edge.layout.api;

import jakarta.validation.constraints.NotBlank;

public record CreateDiningTableRequest(
		@NotBlank String label,
		Integer floorIndex,
		String shape,
		Integer seatCount,
		Double layoutPosX,
		Double layoutPosY,
		Double layoutWidth,
		Double layoutHeight) {
}
