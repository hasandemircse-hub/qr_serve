package com.qr.common.billing.fiscal;

import java.util.Optional;

public record FiscalSubmitResult(boolean success, String providerReference, String rawResponse,
		Optional<String> correlationId) {

	public static FiscalSubmitResult ok(String providerReference, String rawResponse) {
		return new FiscalSubmitResult(true, providerReference, rawResponse, Optional.empty());
	}

	public static FiscalSubmitResult failed(String rawResponse) {
		return new FiscalSubmitResult(false, null, rawResponse, Optional.empty());
	}
}
