package com.qr.edge.layout;

import java.util.UUID;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.layout.api.FloorLayoutBroadcast;
import com.qr.edge.layout.api.FloorLayoutPutRequest;
import com.qr.edge.layout.api.TableAvailabilityPatchRequest;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}/layout")
@CrossOrigin(originPatterns = { "http://localhost:*", "http://127.0.0.1:*" })
public class FloorLayoutRestController {

	private final FloorLayoutService floorLayoutService;

	public FloorLayoutRestController(FloorLayoutService floorLayoutService) {
		this.floorLayoutService = floorLayoutService;
	}

	@GetMapping
	@PreAuthorize("@edgeAuth.canViewFloorPlan(authentication, #restaurantId)")
	public FloorLayoutBroadcast getLayout(@PathVariable UUID restaurantId) {
		return floorLayoutService.buildSnapshot(restaurantId);
	}

	@PutMapping
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public FloorLayoutBroadcast putLayout(
			@PathVariable UUID restaurantId,
			@Valid @RequestBody FloorLayoutPutRequest body) {
		return floorLayoutService.applyLayout(restaurantId, body);
	}

	@PatchMapping("/tables/{tableId}/availability")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public FloorLayoutBroadcast patchAvailability(
			@PathVariable UUID restaurantId,
			@PathVariable UUID tableId,
			@Valid @RequestBody TableAvailabilityPatchRequest body) {
		return floorLayoutService.updateAvailability(restaurantId, tableId, body.availabilityStatus());
	}
}
