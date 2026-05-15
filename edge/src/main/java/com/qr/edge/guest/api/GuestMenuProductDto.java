package com.qr.edge.guest.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record GuestMenuProductDto(UUID id, String name, String description, BigDecimal price) {
}
