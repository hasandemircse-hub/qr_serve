package com.qr.edge.guest;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * Uygulama yüklemeden QR menü: tek sayfa istemci {@code /guest/index.html} üzerinden sunulur.
 */
@Controller
public class GuestMenuSpaController {

	@GetMapping("/r/{restaurantId}/t/{tableId}/{token}")
	public String guestQrMenuSpa(
			@PathVariable String restaurantId,
			@PathVariable String tableId,
			@PathVariable String token) {
		return "forward:/guest/index.html";
	}
}
