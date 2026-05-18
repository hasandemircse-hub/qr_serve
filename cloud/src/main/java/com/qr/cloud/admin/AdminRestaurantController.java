package com.qr.cloud.admin;

import java.util.List;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.security.SubscriptionStatus;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/admin/restaurants")
@Profile("!test")
@PreAuthorize("hasRole('SUPERADMIN')")
public class AdminRestaurantController {

	private final RestaurantRepository restaurantRepository;

	private final AdminEdgeMonitoringService adminEdgeMonitoringService;

	public AdminRestaurantController(
			RestaurantRepository restaurantRepository,
			AdminEdgeMonitoringService adminEdgeMonitoringService) {
		this.restaurantRepository = restaurantRepository;
		this.adminEdgeMonitoringService = adminEdgeMonitoringService;
	}

	@GetMapping
	public List<AdminRestaurantOverviewDto> list() {
		return adminEdgeMonitoringService.restaurantOverview();
	}

	@PostMapping
	@Transactional
	public AdminRestaurantOverviewDto create(@Valid @RequestBody CreateRestaurantRequest body) {
		Restaurant restaurant = new Restaurant();
		restaurant.setName(body.name().trim());
		restaurant.setLegalName(trimToNull(body.legalName()));
		restaurant.setTaxId(trimToNull(body.taxId()));
		restaurant.setSubscriptionStatus(body.subscriptionStatus() == null ? SubscriptionStatus.DEMO : body.subscriptionStatus());
		restaurantRepository.save(restaurant);
		return new AdminRestaurantOverviewDto(
				restaurant.getId(),
				restaurant.getName(),
				restaurant.getSubscriptionStatus(),
				null,
				null,
				null,
				null,
				EdgeConnectivityStatus.NEVER_SEEN);
	}

	@PatchMapping("/{id}/subscription")
	@Transactional
	public void patchSubscription(@PathVariable UUID id, @Valid @RequestBody RestaurantSubscriptionPatch body) {
		var r = restaurantRepository.findById(id).orElseThrow();
		r.setSubscriptionStatus(body.subscriptionStatus());
		restaurantRepository.save(r);
	}

	private static String trimToNull(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		return value.trim();
	}
}
