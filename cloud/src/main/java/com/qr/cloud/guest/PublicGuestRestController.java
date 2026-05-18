package com.qr.cloud.guest;

import java.util.UUID;

import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/public/guest/r/{restaurantId}/t/{tableId}/{token}")
@CrossOrigin(originPatterns = { "http://localhost:*", "http://127.0.0.1:*", "https://localhost:*", "https://127.0.0.1:*" })
public class PublicGuestRestController {

	private final EdgeGuestProxyService edgeGuestProxyService;

	public PublicGuestRestController(EdgeGuestProxyService edgeGuestProxyService) {
		this.edgeGuestProxyService = edgeGuestProxyService;
	}

	@GetMapping("/session")
	public ResponseEntity<String> session(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		return edgeGuestProxyService.forwardSession(restaurantId, guestSuffix(restaurantId, tableId, token, "/session"));
	}

	@GetMapping("/menu")
	public ResponseEntity<String> menu(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		return edgeGuestProxyService.forward(
				HttpMethod.GET, restaurantId, guestSuffix(restaurantId, tableId, token, "/menu"), null);
	}

	@GetMapping("/products/{productId}/option-wizard")
	public ResponseEntity<String> optionWizard(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token,
			@PathVariable UUID productId) {
		return edgeGuestProxyService.forward(
				HttpMethod.GET,
				restaurantId,
				guestSuffix(restaurantId, tableId, token, "/products/" + productId + "/option-wizard"),
				null);
	}

	@GetMapping("/orders/open")
	public ResponseEntity<String> ordersOpen(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token) {
		return edgeGuestProxyService.forward(
				HttpMethod.GET,
				restaurantId,
				guestSuffix(restaurantId, tableId, token, "/orders/open"),
				null);
	}

	@PostMapping(value = "/orders", consumes = MediaType.APPLICATION_JSON_VALUE)
	public ResponseEntity<String> orders(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token,
			@RequestBody String body) {
		return edgeGuestProxyService.forward(
				HttpMethod.POST, restaurantId, guestSuffix(restaurantId, tableId, token, "/orders"), body);
	}

	@PostMapping(value = "/service-requests", consumes = MediaType.APPLICATION_JSON_VALUE)
	public ResponseEntity<String> serviceRequests(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@PathVariable String token,
			@RequestBody String body) {
		return edgeGuestProxyService.forward(
				HttpMethod.POST,
				restaurantId,
				guestSuffix(restaurantId, tableId, token, "/service-requests"),
				body);
	}

	private static String guestSuffix(UUID restaurantId, UUID tableId, String token, String suffix) {
		return "/" + restaurantId + "/t/" + tableId + "/" + token + suffix;
	}
}
