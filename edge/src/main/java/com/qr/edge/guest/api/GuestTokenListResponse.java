package com.qr.edge.guest.api;

import java.util.List;
import java.util.UUID;

public record GuestTokenListResponse(UUID billingTableId, List<GuestTokenRowDto> tokens) {
}
