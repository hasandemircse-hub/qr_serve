package com.qr.edge.guest.events;

import java.util.UUID;

public record KitchenLineGuestNotifyEvent(UUID orderId, UUID lineId) {
}
