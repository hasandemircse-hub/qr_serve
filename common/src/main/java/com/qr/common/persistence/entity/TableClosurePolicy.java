package com.qr.common.persistence.entity;

public enum TableClosurePolicy {
	STANDARD,
	FORCE_CLOSE_UNPAID,
	/** Kalan bakiye bırakılarak masa boşaltılır; adisyon DEFERRED kalır. */
	DEFER_BALANCE
}
