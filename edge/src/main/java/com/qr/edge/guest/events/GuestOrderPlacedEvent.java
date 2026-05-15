package com.qr.edge.guest.events;

import java.util.UUID;

public record GuestOrderPlacedEvent(UUID orderId) {
}
