package com.qr.edge.waiter.api;

import java.util.List;
import java.util.UUID;

import com.qr.edge.qr.api.CreateQrOrderRequest.QrOrderLineRequest;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

public record WaiterPlaceOrderRequest(
		@NotNull UUID tableId,
		@NotEmpty @Valid List<QrOrderLineRequest> lines) {
}
