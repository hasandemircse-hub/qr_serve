package com.qr.common.persistence.entity;

/**
 * Ödeme ana tutarının hesaba nasıl uygulanacağı.
 */
public enum PaymentAllocationKind {
	/** Belirli satırlara (veya satır parçalarına) uygulanır. */
	PRODUCT_LINES,
	/** Hesaptan sabit tutar kapatılır (kalan satırlara FIFO dağıtım). */
	FIXED_AMOUNT,
	/** Açık kalan bakiyenin tamamı kapatılır. */
	REMAINDER
}
