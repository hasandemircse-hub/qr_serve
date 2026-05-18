package com.qr.common.persistence.entity;

public enum OrderStatus {
	DRAFT,
	OPEN,
	IN_PROGRESS,
	READY,
	SERVED,
	CLOSED,
	/** Masa boşaltıldı; tahsilat sonraya bırakıldı (kurumsal hesap vb.). */
	DEFERRED,
	CANCELLED
}
