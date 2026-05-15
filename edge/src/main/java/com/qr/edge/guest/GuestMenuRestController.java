package com.qr.edge.guest;

import java.util.UUID;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.guest.api.GuestCartOrderRequest;
import com.qr.edge.guest.api.GuestMenuPayload;
import com.qr.edge.guest.api.GuestOrderStatusResponse;
import com.qr.edge.guest.api.GuestServiceRequestBody;
import com.qr.edge.guest.api.GuestSessionResponse;
import com.qr.edge.qr.api.CreateQrOrderResponse;
import com.qr.edge.qr.api.ProductOptionWizardResponse;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/guest/r/{restaurantId}/t/{tableId}/{token}")
@CrossOrigin(originPatterns = { "http://localhost:*", "http://127.0.0.1:*" })
public class GuestMenuRestController {

	private final GuestMenuService guestMenuService;

	public GuestMenuRestController(GuestMenuService guestMenuService) {
		this.guestMenuService = guestMenuService;
	}

	@GetMapping("/session")
	public GuestSessionResponse session(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		return guestMenuService.session(restaurantId, tableId, token);
	}

	@GetMapping("/menu")
	public GuestMenuPayload menu(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		return guestMenuService.menu(restaurantId, tableId, token);
	}

	@GetMapping("/products/{productId}/option-wizard")
	public ProductOptionWizardResponse guestProductOptionWizard(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token,
			@PathVariable UUID productId) {
		return guestMenuService.productOptionWizard(restaurantId, tableId, token, productId);
	}

	@GetMapping("/orders/open")
	public GuestOrderStatusResponse guestOrdersOpen(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		return guestMenuService.listGuestOrdersSnapshot(restaurantId, tableId, token);
	}

	@PostMapping("/orders")
	public CreateQrOrderResponse orders(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token,
			@Valid @RequestBody GuestCartOrderRequest body) {
		return guestMenuService.placeOrder(restaurantId, tableId, token, body);
	}

	@PostMapping("/service-requests")
	public void serviceRequests(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token,
			@Valid @RequestBody GuestServiceRequestBody body) {
		guestMenuService.serviceRequest(restaurantId, tableId, token, body);
	}
}
