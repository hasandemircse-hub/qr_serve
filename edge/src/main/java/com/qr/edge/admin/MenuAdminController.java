package com.qr.edge.admin;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.admin.api.AdminMenuTreeResponse;
import com.qr.edge.admin.api.AdminMenuTreeResponse.AdminMenuDetailDto;
import com.qr.edge.admin.api.AdminMenuTreeResponse.AdminProductDetailDto;
import com.qr.edge.admin.api.UpsertMenuRequest;
import com.qr.edge.admin.api.UpsertProductRequest;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}")
public class MenuAdminController {

	private final MenuAdminService menuAdminService;

	public MenuAdminController(MenuAdminService menuAdminService) {
		this.menuAdminService = menuAdminService;
	}

	@GetMapping("/menus/tree")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminMenuTreeResponse menuTree(@PathVariable UUID restaurantId) {
		return menuAdminService.listTree(restaurantId);
	}

	@PostMapping("/menus")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminMenuDetailDto createMenu(
			@PathVariable UUID restaurantId,
			@Valid @RequestBody UpsertMenuRequest body) {
		return menuAdminService.createMenu(restaurantId, body);
	}

	@PutMapping("/menus/{menuId}")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminMenuDetailDto updateMenu(
			@PathVariable UUID restaurantId,
			@PathVariable UUID menuId,
			@Valid @RequestBody UpsertMenuRequest body) {
		return menuAdminService.updateMenu(restaurantId, menuId, body);
	}

	@DeleteMapping("/menus/{menuId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void deleteMenu(@PathVariable UUID restaurantId, @PathVariable UUID menuId) {
		menuAdminService.deleteMenu(restaurantId, menuId);
	}

	@PostMapping("/menus/{menuId}/products")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminProductDetailDto createProduct(
			@PathVariable UUID restaurantId,
			@PathVariable UUID menuId,
			@Valid @RequestBody UpsertProductRequest body) {
		return menuAdminService.createProduct(restaurantId, menuId, body);
	}

	@PutMapping("/products/{productId}")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public AdminProductDetailDto updateProduct(
			@PathVariable UUID restaurantId,
			@PathVariable UUID productId,
			@Valid @RequestBody UpsertProductRequest body) {
		return menuAdminService.updateProduct(restaurantId, productId, body);
	}

	@DeleteMapping("/products/{productId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void deleteProduct(@PathVariable UUID restaurantId, @PathVariable UUID productId) {
		menuAdminService.deleteProduct(restaurantId, productId);
	}
}
