package com.qr.edge.kitchen.api;

import java.util.List;

public record KitchenQueuePayload(List<KitchenQueueLineRow> lines) {
}
