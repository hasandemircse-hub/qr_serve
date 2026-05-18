package com.qr.edge.billing.api;

import jakarta.validation.constraints.Size;

public record RefundPaymentRequest(
		@Size(max = 500) String note) {
}
