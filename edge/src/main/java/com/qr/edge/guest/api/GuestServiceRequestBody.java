package com.qr.edge.guest.api;

import com.qr.common.persistence.entity.GuestServiceRequestType;

import jakarta.validation.constraints.NotNull;

public record GuestServiceRequestBody(@NotNull GuestServiceRequestType type) {
}
