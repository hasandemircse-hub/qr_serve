package com.qr.edge.info;

import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.edge.config.QuickserveProperties;

@RestController
@RequestMapping("/api/v1/edge")
@Profile("!test")
public class EdgeInfoController {

	private final QuickserveProperties properties;

	private final RestaurantRepository restaurantRepository;

	private final Environment environment;

	public EdgeInfoController(
			QuickserveProperties properties,
			RestaurantRepository restaurantRepository,
			Environment environment) {
		this.properties = properties;
		this.restaurantRepository = restaurantRepository;
		this.environment = environment;
	}

	@GetMapping("/info")
	public EdgeInfoResponse info() {
		String restaurantName = restaurantRepository.findById(properties.getRestaurantId())
				.map(r -> r.getName())
				.orElse(null);
		String profiles = String.join(",", environment.getActiveProfiles());
		if (profiles.isEmpty()) {
			profiles = "default";
		}
		return new EdgeInfoResponse(
				properties.getEdgeId(),
				properties.getRestaurantId(),
				restaurantName,
				properties.getCloud().getBaseUrl(),
				properties.getEdge().getSync().isEnabled(),
				profiles);
	}
}
