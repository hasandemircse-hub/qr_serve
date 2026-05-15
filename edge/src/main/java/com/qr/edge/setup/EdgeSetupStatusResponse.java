package com.qr.edge.setup;

import java.util.UUID;

public record EdgeSetupStatusResponse(
		boolean needsWizard,
		String currentStep,
		boolean cloudReachable,
		UUID edgeId,
		UUID restaurantId,
		boolean cloudMock,
		String mode) {
}
