package com.qr.edge.guest;

import java.util.UUID;

/** Misafir QR yolu: Cloud {@code GET /r/...} ve Edge SPA ile aynı path. */
public final class GuestQrLinks {

	private GuestQrLinks() {
	}

	public static String path(UUID restaurantId, UUID tableId, String token) {
		return "/r/" + restaurantId + "/t/" + tableId + "/" + token;
	}

	public static String absolute(String baseUrl, UUID restaurantId, UUID tableId, String token) {
		return normalizeBase(baseUrl) + path(restaurantId, tableId, token);
	}

	public static String normalizeBase(String baseUrl) {
		if (baseUrl == null || baseUrl.isBlank()) {
			return "";
		}
		return baseUrl.trim().replaceAll("/+$", "");
	}
}
