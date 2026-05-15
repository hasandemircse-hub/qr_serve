package com.qr.edge.layout.api;

import com.qr.common.persistence.entity.TableAvailabilityStatus;

import jakarta.validation.constraints.NotNull;

public record TableAvailabilityPatchRequest(@NotNull TableAvailabilityStatus availabilityStatus) {
}
