package com.qr.edge.guest.api;

import java.util.List;
import java.util.UUID;

public record GuestMenuMenuDto(UUID id, String name, List<GuestMenuProductDto> products) {
}
