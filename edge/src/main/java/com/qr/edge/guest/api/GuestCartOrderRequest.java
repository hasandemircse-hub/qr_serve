package com.qr.edge.guest.api;

import java.util.List;

import com.qr.edge.qr.api.CreateQrOrderRequest.QrOrderLineRequest;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

public record GuestCartOrderRequest(@NotEmpty @Valid List<QrOrderLineRequest> lines) {
}
