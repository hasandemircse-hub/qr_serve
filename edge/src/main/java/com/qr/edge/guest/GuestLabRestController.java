package com.qr.edge.guest;

import java.util.UUID;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.guest.api.GuestLabTablesResponse;

@RestController
@RequestMapping("/api/v1/guest/lab")
@CrossOrigin(originPatterns = {
		"http://localhost:*",
		"http://127.0.0.1:*",
		"http://192.168.*:*",
		"http://10.*:*"
})
@ConditionalOnProperty(prefix = "quickserve", name = "guest-lab-enabled", havingValue = "true")
public class GuestLabRestController {

	private final GuestLabService guestLabService;

	public GuestLabRestController(GuestLabService guestLabService) {
		this.guestLabService = guestLabService;
	}

	@GetMapping("/restaurants/{restaurantId}/tables")
	public GuestLabTablesResponse tables(@PathVariable UUID restaurantId) {
		return guestLabService.listTablesWithGuestLinks(restaurantId);
	}
}
