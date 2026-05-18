package com.qr.edge.guest;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.guest.api.GuestPhoneQrLink;
import com.qr.edge.guest.api.GuestTokenListResponse;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}/tables/{tableId}/guest-tokens")
public class GuestTokenAdminController {

	private final GuestTokenAdminService guestTokenAdminService;

	public GuestTokenAdminController(GuestTokenAdminService guestTokenAdminService) {
		this.guestTokenAdminService = guestTokenAdminService;
	}

	@GetMapping
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public GuestTokenListResponse list(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId) {
		return guestTokenAdminService.listTokens(restaurantId, tableId);
	}

	@PostMapping("/rotate")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public GuestPhoneQrLink rotate(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId) {
		return guestTokenAdminService.rotateToken(restaurantId, tableId);
	}

	@DeleteMapping
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void revokeAll(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId) {
		guestTokenAdminService.revokeAllForTable(restaurantId, tableId);
	}
}
