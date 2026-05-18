package com.qr.edge.billing.api;

import com.qr.common.persistence.entity.TableClosureBalanceDisposition;
import com.qr.common.persistence.entity.TableClosurePolicy;
import com.qr.common.persistence.entity.TableClosureReasonCode;

public record CloseTableSessionRequest(
		TableClosurePolicy policy,
		TableClosureReasonCode reasonCode,
		TableClosureBalanceDisposition balanceDisposition,
		String note) {
}
