package com.qr.edge.guest;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}/guest-tokens")
public class GuestTokenRevokeController {

	private final GuestTokenAdminService guestTokenAdminService;

	public GuestTokenRevokeController(GuestTokenAdminService guestTokenAdminService) {
		this.guestTokenAdminService = guestTokenAdminService;
	}

	@DeleteMapping("/{tokenId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void revoke(@PathVariable UUID restaurantId, @PathVariable UUID tokenId) {
		guestTokenAdminService.revokeToken(restaurantId, tokenId);
	}
}
