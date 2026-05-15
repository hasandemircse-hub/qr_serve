package com.qr.edge.kitchen;

import java.util.UUID;

public record KitchenLineReadyEvent(UUID orderId, UUID lineId) {
}
