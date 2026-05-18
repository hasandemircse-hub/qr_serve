package com.qr.edge.admin;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.ProductOption;
import com.qr.common.persistence.entity.ProductOptionGroup;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.ProductOptionGroupRepository;
import com.qr.common.persistence.repository.ProductOptionRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.edge.admin.api.AdminMenuTreeResponse;
import com.qr.edge.admin.api.AdminMenuTreeResponse.AdminMenuDetailDto;
import com.qr.edge.admin.api.AdminMenuTreeResponse.AdminProductDetailDto;
import com.qr.edge.admin.api.UpsertMenuRequest;
import com.qr.edge.admin.api.UpsertProductRequest;

@Service
public class MenuAdminService {

	private final Clock clock;

	private final RestaurantRepository restaurantRepository;

	private final MenuRepository menuRepository;

	private final ProductRepository productRepository;

	private final ProductOptionGroupRepository productOptionGroupRepository;

	private final ProductOptionRepository productOptionRepository;

	public MenuAdminService(
			Clock clock,
			RestaurantRepository restaurantRepository,
			MenuRepository menuRepository,
			ProductRepository productRepository,
			ProductOptionGroupRepository productOptionGroupRepository,
			ProductOptionRepository productOptionRepository) {
		this.clock = clock;
		this.restaurantRepository = restaurantRepository;
		this.menuRepository = menuRepository;
		this.productRepository = productRepository;
		this.productOptionGroupRepository = productOptionGroupRepository;
		this.productOptionRepository = productOptionRepository;
	}

	public AdminMenuTreeResponse listTree(UUID restaurantId) {
		requireRestaurant(restaurantId);
		List<AdminMenuDetailDto> menus = new ArrayList<>();
		for (Menu menu : menuRepository.findByRestaurantIdAndIsDeletedFalseOrderByNameAsc(restaurantId)) {
			List<AdminProductDetailDto> products = new ArrayList<>();
			for (Product p : productRepository.findByMenuIdAndIsDeletedFalseOrderByNameAsc(menu.getId())) {
				products.add(toProductDto(p));
			}
			menus.add(new AdminMenuDetailDto(
					menu.getId(),
					menu.getName(),
					menu.getDescription(),
					Boolean.TRUE.equals(menu.getActive()),
					products));
		}
		return new AdminMenuTreeResponse(menus);
	}

	@Transactional
	public AdminMenuDetailDto createMenu(UUID restaurantId, UpsertMenuRequest body) {
		requireRestaurant(restaurantId);
		Menu menu = new Menu();
		menu.setRestaurantId(restaurantId);
		menu.setName(body.name().trim());
		menu.setDescription(trimToNull(body.description()));
		menu.setActive(body.active() == null || body.active());
		menu.assignIdIfAbsent();
		menuRepository.save(menu);
		return new AdminMenuDetailDto(menu.getId(), menu.getName(), menu.getDescription(), menu.getActive(), List.of());
	}

	@Transactional
	public AdminMenuDetailDto updateMenu(UUID restaurantId, UUID menuId, UpsertMenuRequest body) {
		Menu menu = requireMenuInRestaurant(restaurantId, menuId);
		menu.setName(body.name().trim());
		menu.setDescription(trimToNull(body.description()));
		if (body.active() != null) {
			menu.setActive(body.active());
		}
		menu.setUpdatedAt(LocalDateTime.now(clock));
		menuRepository.save(menu);
		return toMenuDto(menu);
	}

	@Transactional
	public void deleteMenu(UUID restaurantId, UUID menuId) {
		Menu menu = requireMenuInRestaurant(restaurantId, menuId);
		LocalDateTime now = LocalDateTime.now(clock);
		menu.setIsDeleted(true);
		menu.setUpdatedAt(now);
		menuRepository.save(menu);
		for (Product product : productRepository.findByMenuIdAndIsDeletedFalseOrderByNameAsc(menuId)) {
			softDeleteProduct(product, now);
		}
	}

	@Transactional
	public AdminProductDetailDto createProduct(UUID restaurantId, UUID menuId, UpsertProductRequest body) {
		requireMenuInRestaurant(restaurantId, menuId);
		Product product = new Product();
		product.setMenuId(menuId);
		applyProductFields(product, body);
		product.assignIdIfAbsent();
		productRepository.save(product);
		return toProductDto(product);
	}

	@Transactional
	public AdminProductDetailDto updateProduct(UUID restaurantId, UUID productId, UpsertProductRequest body) {
		Product product = requireProductInRestaurant(restaurantId, productId);
		if (body.menuId() != null && !body.menuId().equals(product.getMenuId())) {
			requireMenuInRestaurant(restaurantId, body.menuId());
			product.setMenuId(body.menuId());
		}
		applyProductFields(product, body);
		product.setUpdatedAt(LocalDateTime.now(clock));
		productRepository.save(product);
		return toProductDto(product);
	}

	@Transactional
	public void deleteProduct(UUID restaurantId, UUID productId) {
		Product product = requireProductInRestaurant(restaurantId, productId);
		softDeleteProduct(product, LocalDateTime.now(clock));
	}

	private void applyProductFields(Product product, UpsertProductRequest body) {
		product.setName(body.name().trim());
		product.setDescription(trimToNull(body.description()));
		product.setPrice(body.price());
		product.setSku(trimToNull(body.sku()));
		if (body.taxRate() != null) {
			if (body.taxRate().compareTo(BigDecimal.ONE) > 0) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "taxRate must be between 0 and 1");
			}
			product.setTaxRate(body.taxRate());
		}
	}

	private void softDeleteProduct(Product product, LocalDateTime now) {
		if (Boolean.TRUE.equals(product.getIsDeleted())) {
			return;
		}
		product.setIsDeleted(true);
		product.setUpdatedAt(now);
		productRepository.save(product);
		for (ProductOptionGroup group : productOptionGroupRepository
				.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(product.getId())) {
			group.setIsDeleted(true);
			group.setUpdatedAt(now);
			productOptionGroupRepository.save(group);
			for (ProductOption opt : productOptionRepository
					.findByOptionGroupIdOrderBySortIndexAsc(group.getId())) {
				if (!Boolean.TRUE.equals(opt.getIsDeleted())) {
					opt.setIsDeleted(true);
					opt.setUpdatedAt(now);
					productOptionRepository.save(opt);
				}
			}
		}
	}

	private AdminMenuDetailDto toMenuDto(Menu menu) {
		List<AdminProductDetailDto> products = new ArrayList<>();
		for (Product p : productRepository.findByMenuIdAndIsDeletedFalseOrderByNameAsc(menu.getId())) {
			products.add(toProductDto(p));
		}
		return new AdminMenuDetailDto(
				menu.getId(),
				menu.getName(),
				menu.getDescription(),
				Boolean.TRUE.equals(menu.getActive()),
				products);
	}

	private static AdminProductDetailDto toProductDto(Product p) {
		return new AdminProductDetailDto(
				p.getId(),
				p.getName(),
				p.getDescription(),
				p.getPrice(),
				p.getSku(),
				p.getTaxRate());
	}

	private void requireRestaurant(UUID restaurantId) {
		if (!restaurantRepository.existsById(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found");
		}
	}

	private Menu requireMenuInRestaurant(UUID restaurantId, UUID menuId) {
		requireRestaurant(restaurantId);
		return menuRepository.findById(menuId)
				.filter(m -> !Boolean.TRUE.equals(m.getIsDeleted()))
				.filter(m -> restaurantId.equals(m.getRestaurantId()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu not found"));
	}

	private Product requireProductInRestaurant(UUID restaurantId, UUID productId) {
		Product product = productRepository.findById(productId)
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
		requireMenuInRestaurant(restaurantId, product.getMenuId());
		return product;
	}

	private static String trimToNull(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		return value.trim();
	}
}
