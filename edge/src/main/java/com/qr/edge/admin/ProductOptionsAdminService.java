package com.qr.edge.admin;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.function.BiConsumer;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.OptionSelectionType;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.ProductOption;
import com.qr.common.persistence.entity.ProductOptionGroup;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.ProductOptionGroupRepository;
import com.qr.common.persistence.repository.ProductOptionRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.edge.admin.api.AdminMenuProductsResponse;
import com.qr.edge.admin.api.AdminMenuProductsResponse.AdminMenuDto;
import com.qr.edge.admin.api.AdminMenuProductsResponse.AdminProductDto;
import com.qr.edge.admin.api.AdminProductOptionGroupsResponse;
import com.qr.edge.admin.api.AdminProductOptionGroupsResponse.AdminOptionGroupDto;
import com.qr.edge.admin.api.AdminProductOptionGroupsResponse.AdminOptionItemDto;
import com.qr.edge.admin.api.ReorderIdsRequest;
import com.qr.edge.admin.api.UpsertOptionGroupRequest;
import com.qr.edge.admin.api.UpsertProductOptionRequest;

@Service
public class ProductOptionsAdminService {

	private final Clock clock;

	private final RestaurantRepository restaurantRepository;

	private final MenuRepository menuRepository;

	private final ProductRepository productRepository;

	private final ProductOptionGroupRepository productOptionGroupRepository;

	private final ProductOptionRepository productOptionRepository;

	public ProductOptionsAdminService(
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

	public AdminMenuProductsResponse listMenuProducts(UUID restaurantId) {
		requireRestaurant(restaurantId);
		List<AdminMenuDto> menus = new ArrayList<>();
		for (Menu menu : menuRepository.findByRestaurantIdAndIsDeletedFalseOrderBySortIndexAscNameAsc(restaurantId)) {
			List<AdminProductDto> products = new ArrayList<>();
			for (Product p : productRepository.findByMenuIdAndIsDeletedFalseOrderBySortIndexAscNameAsc(menu.getId())) {
				int groupCount = productOptionGroupRepository
						.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(p.getId())
						.size();
				products.add(new AdminProductDto(p.getId(), p.getName(), p.getPrice(), groupCount));
			}
			menus.add(new AdminMenuDto(menu.getId(), menu.getName(), products));
		}
		return new AdminMenuProductsResponse(menus);
	}

	public AdminProductOptionGroupsResponse listOptionGroups(UUID restaurantId, UUID productId) {
		Product product = requireProductInRestaurant(restaurantId, productId);
		List<AdminOptionGroupDto> groups = new ArrayList<>();
		for (ProductOptionGroup g : productOptionGroupRepository
				.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(productId)) {
			List<AdminOptionItemDto> options = new ArrayList<>();
			for (ProductOption o : productOptionRepository
					.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(g.getId())) {
				options.add(new AdminOptionItemDto(
						o.getId(),
						o.getLabel(),
						o.getPriceAdjustment() != null ? o.getPriceAdjustment() : BigDecimal.ZERO,
						o.getSortIndex() != null ? o.getSortIndex() : 0));
			}
			groups.add(new AdminOptionGroupDto(
					g.getId(),
					g.getName(),
					g.getSelectionType().name(),
					g.getSortIndex() != null ? g.getSortIndex() : 0,
					options));
		}
		return new AdminProductOptionGroupsResponse(product.getId(), product.getName(), groups);
	}

	@Transactional
	public AdminOptionGroupDto createOptionGroup(UUID restaurantId, UUID productId, UpsertOptionGroupRequest body) {
		requireProductInRestaurant(restaurantId, productId);
		LocalDateTime now = LocalDateTime.now(clock);
		ProductOptionGroup group = new ProductOptionGroup();
		group.setProductId(productId);
		group.setName(body.name().trim());
		group.setSelectionType(parseSelectionType(body.selectionType()));
		group.setSortIndex(resolveSortIndex(body.sortIndex(), productId));
		group.assignIdIfAbsent();
		productOptionGroupRepository.save(group);
		return new AdminOptionGroupDto(
				group.getId(),
				group.getName(),
				group.getSelectionType().name(),
				group.getSortIndex(),
				List.of());
	}

	@Transactional
	public AdminOptionGroupDto updateOptionGroup(
			UUID restaurantId,
			UUID groupId,
			UpsertOptionGroupRequest body) {
		ProductOptionGroup group = requireGroupInRestaurant(restaurantId, groupId);
		group.setName(body.name().trim());
		group.setSelectionType(parseSelectionType(body.selectionType()));
		if (body.sortIndex() != null) {
			group.setSortIndex(body.sortIndex());
		}
		group.setUpdatedAt(LocalDateTime.now(clock));
		productOptionGroupRepository.save(group);
		return toGroupDto(group);
	}

	@Transactional
	public void deleteOptionGroup(UUID restaurantId, UUID groupId) {
		ProductOptionGroup group = requireGroupInRestaurant(restaurantId, groupId);
		LocalDateTime now = LocalDateTime.now(clock);
		group.setIsDeleted(true);
		group.setUpdatedAt(now);
		productOptionGroupRepository.save(group);
		for (ProductOption opt : productOptionRepository.findByOptionGroupIdOrderBySortIndexAsc(groupId)) {
			if (!Boolean.TRUE.equals(opt.getIsDeleted())) {
				opt.setIsDeleted(true);
				opt.setUpdatedAt(now);
				productOptionRepository.save(opt);
			}
		}
	}

	@Transactional
	public AdminOptionItemDto createOption(
			UUID restaurantId,
			UUID groupId,
			UpsertProductOptionRequest body) {
		ProductOptionGroup group = requireGroupInRestaurant(restaurantId, groupId);
		ProductOption opt = new ProductOption();
		opt.setOptionGroupId(group.getId());
		opt.setLabel(body.label().trim());
		opt.setPriceAdjustment(body.priceAdjustment());
		opt.setSortIndex(resolveOptionSortIndex(body.sortIndex(), group.getId()));
		opt.assignIdIfAbsent();
		productOptionRepository.save(opt);
		return new AdminOptionItemDto(opt.getId(), opt.getLabel(), opt.getPriceAdjustment(), opt.getSortIndex());
	}

	@Transactional
	public AdminOptionItemDto updateOption(
			UUID restaurantId,
			UUID optionId,
			UpsertProductOptionRequest body) {
		ProductOption opt = requireOptionInRestaurant(restaurantId, optionId);
		opt.setLabel(body.label().trim());
		opt.setPriceAdjustment(body.priceAdjustment());
		if (body.sortIndex() != null) {
			opt.setSortIndex(body.sortIndex());
		}
		opt.setUpdatedAt(LocalDateTime.now(clock));
		productOptionRepository.save(opt);
		return new AdminOptionItemDto(opt.getId(), opt.getLabel(), opt.getPriceAdjustment(), opt.getSortIndex());
	}

	@Transactional
	public void deleteOption(UUID restaurantId, UUID optionId) {
		ProductOption opt = requireOptionInRestaurant(restaurantId, optionId);
		opt.setIsDeleted(true);
		opt.setUpdatedAt(LocalDateTime.now(clock));
		productOptionRepository.save(opt);
	}

	@Transactional
	public void reorderOptionGroups(UUID restaurantId, UUID productId, ReorderIdsRequest request) {
		requireProductInRestaurant(restaurantId, productId);
		applySortOrder(
				productOptionGroupRepository
						.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(productId)
						.stream()
						.map(ProductOptionGroup::getId)
						.toList(),
				request.orderedIds(),
				(index, id) -> {
					ProductOptionGroup group = requireGroupInRestaurant(restaurantId, id);
					if (!group.getProductId().equals(productId)) {
						throw new ResponseStatusException(
								HttpStatus.BAD_REQUEST,
								"Option group does not belong to product");
					}
					group.setSortIndex(index);
					group.setUpdatedAt(LocalDateTime.now(clock));
					productOptionGroupRepository.save(group);
				});
	}

	@Transactional
	public void reorderOptions(UUID restaurantId, UUID groupId, ReorderIdsRequest request) {
		requireGroupInRestaurant(restaurantId, groupId);
		applySortOrder(
				productOptionRepository.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(groupId).stream()
						.map(ProductOption::getId)
						.toList(),
				request.orderedIds(),
				(index, id) -> {
					ProductOption opt = requireOptionInRestaurant(restaurantId, id);
					if (!opt.getOptionGroupId().equals(groupId)) {
						throw new ResponseStatusException(
								HttpStatus.BAD_REQUEST,
								"Option does not belong to group");
					}
					opt.setSortIndex(index);
					opt.setUpdatedAt(LocalDateTime.now(clock));
					productOptionRepository.save(opt);
				});
	}

	private AdminOptionGroupDto toGroupDto(ProductOptionGroup group) {
		List<AdminOptionItemDto> options = new ArrayList<>();
		for (ProductOption o : productOptionRepository
				.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(group.getId())) {
			options.add(new AdminOptionItemDto(
					o.getId(),
					o.getLabel(),
					o.getPriceAdjustment() != null ? o.getPriceAdjustment() : BigDecimal.ZERO,
					o.getSortIndex() != null ? o.getSortIndex() : 0));
		}
		return new AdminOptionGroupDto(
				group.getId(),
				group.getName(),
				group.getSelectionType().name(),
				group.getSortIndex() != null ? group.getSortIndex() : 0,
				options);
	}

	private int resolveSortIndex(Integer requested, UUID productId) {
		if (requested != null) {
			return requested;
		}
		return productOptionGroupRepository.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(productId).size();
	}

	private int resolveOptionSortIndex(Integer requested, UUID groupId) {
		if (requested != null) {
			return requested;
		}
		return productOptionRepository.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(groupId).size();
	}

	private static void applySortOrder(
			List<UUID> existingIds,
			List<UUID> orderedIds,
			BiConsumer<Integer, UUID> apply) {
		if (orderedIds.size() != existingIds.size()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "orderedIds must include all items");
		}
		Set<UUID> existing = new HashSet<>(existingIds);
		if (!existing.equals(new HashSet<>(orderedIds))) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "orderedIds mismatch");
		}
		for (int i = 0; i < orderedIds.size(); i++) {
			apply.accept(i, orderedIds.get(i));
		}
	}

	private OptionSelectionType parseSelectionType(String raw) {
		if (raw == null || raw.isBlank()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectionType is required");
		}
		try {
			return OptionSelectionType.valueOf(raw.trim().toUpperCase());
		} catch (IllegalArgumentException e) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectionType must be SINGLE or MULTI");
		}
	}

	private void requireRestaurant(UUID restaurantId) {
		if (!restaurantRepository.existsById(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found");
		}
	}

	private Product requireProductInRestaurant(UUID restaurantId, UUID productId) {
		requireRestaurant(restaurantId);
		Product product = productRepository.findById(productId)
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
		Menu menu = menuRepository.findById(product.getMenuId())
				.filter(m -> !Boolean.TRUE.equals(m.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Product menu not found"));
		if (!menu.getRestaurantId().equals(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Product does not belong to restaurant");
		}
		return product;
	}

	private ProductOptionGroup requireGroupInRestaurant(UUID restaurantId, UUID groupId) {
		ProductOptionGroup group = productOptionGroupRepository.findById(groupId)
				.filter(g -> !Boolean.TRUE.equals(g.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Option group not found"));
		requireProductInRestaurant(restaurantId, group.getProductId());
		return group;
	}

	private ProductOption requireOptionInRestaurant(UUID restaurantId, UUID optionId) {
		ProductOption opt = productOptionRepository.findById(optionId)
				.filter(o -> !Boolean.TRUE.equals(o.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Option not found"));
		requireGroupInRestaurant(restaurantId, opt.getOptionGroupId());
		return opt;
	}
}
