package com.qr.common.billing.pos;

/**
 * POS / terminal cevabı (JSON protokolden map'e dönüştürülmüş soyutlama).
 */
public record PosOperationResult(boolean accepted, String terminalReference, String rawResponse) {

	public static PosOperationResult ok(String terminalReference, String rawResponse) {
		return new PosOperationResult(true, terminalReference, rawResponse);
	}

	public static PosOperationResult declined(String rawResponse) {
		return new PosOperationResult(false, null, rawResponse);
	}
}
