package com.qr.edge.admin;

import java.util.UUID;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.admin.api.AdminMenuProductsResponse;
import com.qr.edge.admin.api.AdminProductOptionGroupsResponse;
import com.qr.edge.admin.api.AdminProductOptionGroupsResponse.AdminOptionGroupDto;
import com.qr.edge.admin.api.AdminProductOptionGroupsResponse.AdminOptionItemDto;
import com.qr.edge.admin.api.UpsertOptionGroupRequest;
import com.qr.edge.admin.api.UpsertProductOptionRequest;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}")
public class ProductOptionsAdminController {

	private final ProductOptionsAdminService productOptionsAdminService;

	public ProductOptionsAdminController(ProductOptionsAdminService productOptionsAdminService) {
		this.productOptionsAdminService = productOptionsAdminService;
	}

	@GetMapping("/menu-products")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminMenuProductsResponse menuProducts(@PathVariable UUID restaurantId) {
		return productOptionsAdminService.listMenuProducts(restaurantId);
	}

	@GetMapping("/products/{productId}/option-groups")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminProductOptionGroupsResponse optionGroups(
			@PathVariable UUID restaurantId,
			@PathVariable UUID productId) {
		return productOptionsAdminService.listOptionGroups(restaurantId, productId);
	}

	@PostMapping("/products/{productId}/option-groups")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminOptionGroupDto createOptionGroup(
			@PathVariable UUID restaurantId,
			@PathVariable UUID productId,
			@Valid @RequestBody UpsertOptionGroupRequest body) {
		return productOptionsAdminService.createOptionGroup(restaurantId, productId, body);
	}

	@PutMapping("/option-groups/{groupId}")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminOptionGroupDto updateOptionGroup(
			@PathVariable UUID restaurantId,
			@PathVariable UUID groupId,
			@Valid @RequestBody UpsertOptionGroupRequest body) {
		return productOptionsAdminService.updateOptionGroup(restaurantId, groupId, body);
	}

	@DeleteMapping("/option-groups/{groupId}")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void deleteOptionGroup(@PathVariable UUID restaurantId, @PathVariable UUID groupId) {
		productOptionsAdminService.deleteOptionGroup(restaurantId, groupId);
	}

	@PostMapping("/option-groups/{groupId}/options")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminOptionItemDto createOption(
			@PathVariable UUID restaurantId,
			@PathVariable UUID groupId,
			@Valid @RequestBody UpsertProductOptionRequest body) {
		return productOptionsAdminService.createOption(restaurantId, groupId, body);
	}

	@PutMapping("/options/{optionId}")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminOptionItemDto updateOption(
			@PathVariable UUID restaurantId,
			@PathVariable UUID optionId,
			@Valid @RequestBody UpsertProductOptionRequest body) {
		return productOptionsAdminService.updateOption(restaurantId, optionId, body);
	}

	@DeleteMapping("/options/{optionId}")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void deleteOption(@PathVariable UUID restaurantId, @PathVariable UUID optionId) {
		productOptionsAdminService.deleteOption(restaurantId, optionId);
	}
}
