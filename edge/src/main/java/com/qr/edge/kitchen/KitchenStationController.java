package com.qr.edge.kitchen;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.security.QrUserPrincipal;
import com.qr.edge.kitchen.api.KitchenQueuePayload;


@RestController
@RequestMapping("/api/v1/kitchen")
@CrossOrigin(originPatterns = { "http://localhost:*", "http://127.0.0.1:*" })
public class KitchenStationController {

	private final KitchenLineService kitchenLineService;

	private final KitchenQueueService kitchenQueueService;

	public KitchenStationController(KitchenLineService kitchenLineService, KitchenQueueService kitchenQueueService) {
		this.kitchenLineService = kitchenLineService;
		this.kitchenQueueService = kitchenQueueService;
	}

	@GetMapping("/queue")
	@PreAuthorize("hasAnyRole('KITCHEN','RESTAURANT_ADMIN','SUPERADMIN')")
	public KitchenQueuePayload queue(@AuthenticationPrincipal QrUserPrincipal principal) {
		return kitchenQueueService.buildQueue(requireRestaurant(principal));
	}

	@PostMapping("/orders/{orderId}/lines/{lineId}/received")
	@ResponseStatus(HttpStatus.ACCEPTED)
	@PreAuthorize("hasAnyRole('KITCHEN','RESTAURANT_ADMIN','SUPERADMIN')")
	public void markLineReceived(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@PathVariable UUID orderId,
			@PathVariable UUID lineId) {
		kitchenLineService.markLineReceived(requireRestaurant(principal), orderId, lineId);
	}

	@PostMapping("/orders/{orderId}/lines/{lineId}/ready")
	@ResponseStatus(HttpStatus.ACCEPTED)
	@PreAuthorize("hasAnyRole('KITCHEN','RESTAURANT_ADMIN','SUPERADMIN')")
	public void markLineReady(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@PathVariable UUID orderId,
			@PathVariable UUID lineId) {
		kitchenLineService.markLineKitchenReady(requireRestaurant(principal), orderId, lineId);
	}

	private static UUID requireRestaurant(QrUserPrincipal p) {
		if (p == null || p.restaurantId() == null) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Staff token requires restaurantId");
		}
		return p.restaurantId();
	}
}
