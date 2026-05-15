package com.qr.common.sync;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.Payment;
import com.qr.common.persistence.entity.PaymentAllocationKind;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.ProductOption;
import com.qr.common.persistence.entity.ProductOptionGroup;
import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.entity.User;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.PaymentRepository;
import com.qr.common.persistence.repository.ProductOptionGroupRepository;
import com.qr.common.persistence.repository.ProductOptionRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.UserRepository;
import com.qr.common.sync.api.SyncEntityEnvelope;

/**
 * Edge ↔ Cloud senkron varlıklarının LWW birleştirmesi (çift tarafta aynı mantık).
 */
@Service
@Profile("!test")
public class SyncEntityMergeService {

	private static final LocalDateTime EPOCH = LocalDateTime.of(1970, 1, 1, 0, 0);

	private final ObjectMapper objectMapper;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final MenuRepository menuRepository;

	private final ProductRepository productRepository;

	private final ProductOptionGroupRepository productOptionGroupRepository;

	private final ProductOptionRepository productOptionRepository;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final PaymentRepository paymentRepository;

	private final UserRepository userRepository;

	public SyncEntityMergeService(
			ObjectMapper objectMapper,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			MenuRepository menuRepository,
			ProductRepository productRepository,
			ProductOptionGroupRepository productOptionGroupRepository,
			ProductOptionRepository productOptionRepository,
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			PaymentRepository paymentRepository,
			UserRepository userRepository) {
		this.objectMapper = objectMapper;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.menuRepository = menuRepository;
		this.productRepository = productRepository;
		this.productOptionGroupRepository = productOptionGroupRepository;
		this.productOptionRepository = productOptionRepository;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.paymentRepository = paymentRepository;
		this.userRepository = userRepository;
	}

	public LocalDateTime readUpdatedAtFromEnvelope(SyncEntityEnvelope e) {
		return readUpdatedAtNode(e.payload());
	}

	public SyncApplyResult applyOne(SyncEntityEnvelope envelope) {
		JsonNode payload = envelope.payload();
		return switch (envelope.entityType()) {
			case RESTAURANT -> mergeRestaurant(payload);
			case USER -> mergeUser(payload);
			case DINING_TABLE -> mergeDiningTable(payload);
			case MENU -> mergeMenu(payload);
			case PRODUCT -> mergeProduct(payload);
			case PRODUCT_OPTION_GROUP -> mergeProductOptionGroup(payload);
			case PRODUCT_OPTION -> mergeProductOption(payload);
			case CUSTOMER_ORDER -> mergeOrder(payload);
			case ORDER_LINE_ITEM -> mergeOrderLineItem(payload);
			case PAYMENT -> mergePayment(payload);
		};
	}

	private LocalDateTime readUpdatedAtNode(JsonNode payload) {
		if (payload == null || !payload.has("updatedAt") || payload.get("updatedAt").isNull()) {
			return EPOCH;
		}
		return objectMapper.convertValue(payload.get("updatedAt"), LocalDateTime.class);
	}

	private SyncApplyResult mergeRestaurant(JsonNode payload) {
		Restaurant incoming = objectMapper.convertValue(payload, Restaurant.class);
		return restaurantRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setName(incoming.getName());
					existing.setLegalName(incoming.getLegalName());
					existing.setTaxId(incoming.getTaxId());
					if (incoming.getSubscriptionStatus() != null) {
						existing.setSubscriptionStatus(incoming.getSubscriptionStatus());
					}
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					restaurantRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					restaurantRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeUser(JsonNode payload) {
		User incoming = objectMapper.convertValue(payload, User.class);
		return userRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setRestaurantId(incoming.getRestaurantId());
					existing.setEmail(incoming.getEmail());
					existing.setPasswordHash(incoming.getPasswordHash());
					existing.setRole(incoming.getRole());
					existing.setDisplayName(incoming.getDisplayName());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					userRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					userRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeDiningTable(JsonNode payload) {
		DiningTable incoming = objectMapper.convertValue(payload, DiningTable.class);
		return diningTableRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setRestaurantId(incoming.getRestaurantId());
					existing.setLabel(incoming.getLabel());
					existing.setSeatCount(incoming.getSeatCount());
					existing.setZone(incoming.getZone());
					existing.setLayoutPosX(incoming.getLayoutPosX());
					existing.setLayoutPosY(incoming.getLayoutPosY());
					existing.setLayoutWidth(incoming.getLayoutWidth());
					existing.setLayoutHeight(incoming.getLayoutHeight());
					existing.setLayoutShape(incoming.getLayoutShape());
					existing.setFloorIndex(incoming.getFloorIndex());
					existing.setLayoutGroupId(incoming.getLayoutGroupId());
					existing.setAvailabilityStatus(incoming.getAvailabilityStatus());
					existing.setLayoutRotation(incoming.getLayoutRotation());
					existing.setMergeGroupId(incoming.getMergeGroupId());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					diningTableRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					diningTableRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeMenu(JsonNode payload) {
		Menu incoming = objectMapper.convertValue(payload, Menu.class);
		return menuRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setRestaurantId(incoming.getRestaurantId());
					existing.setName(incoming.getName());
					existing.setDescription(incoming.getDescription());
					existing.setActive(incoming.getActive());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					menuRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					menuRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeProduct(JsonNode payload) {
		Product incoming = objectMapper.convertValue(payload, Product.class);
		return productRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setMenuId(incoming.getMenuId());
					existing.setName(incoming.getName());
					existing.setDescription(incoming.getDescription());
					existing.setPrice(incoming.getPrice());
					existing.setSku(incoming.getSku());
					existing.setTaxRate(incoming.getTaxRate());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					productRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					productRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeProductOptionGroup(JsonNode payload) {
		ProductOptionGroup incoming = objectMapper.convertValue(payload, ProductOptionGroup.class);
		return productOptionGroupRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setProductId(incoming.getProductId());
					existing.setName(incoming.getName());
					existing.setSelectionType(incoming.getSelectionType());
					existing.setSortIndex(incoming.getSortIndex());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					productOptionGroupRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					productOptionGroupRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeProductOption(JsonNode payload) {
		ProductOption incoming = objectMapper.convertValue(payload, ProductOption.class);
		return productOptionRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setOptionGroupId(incoming.getOptionGroupId());
					existing.setLabel(incoming.getLabel());
					existing.setPriceAdjustment(incoming.getPriceAdjustment());
					existing.setSortIndex(incoming.getSortIndex());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					productOptionRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					productOptionRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeOrder(JsonNode payload) {
		RestaurantOrder incoming = objectMapper.convertValue(payload, RestaurantOrder.class);
		return restaurantOrderRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setRestaurantId(incoming.getRestaurantId());
					existing.setTableId(incoming.getTableId());
					existing.setStatus(incoming.getStatus());
					existing.setOrderNumber(incoming.getOrderNumber());
					existing.setOrderedAt(incoming.getOrderedAt());
					existing.setNotes(incoming.getNotes());
					existing.setGuestToken(incoming.getGuestToken());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					restaurantOrderRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					restaurantOrderRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergeOrderLineItem(JsonNode payload) {
		OrderLineItem incoming = objectMapper.convertValue(payload, OrderLineItem.class);
		normalizeOrderLineItemDefaults(incoming);
		return orderLineItemRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setOrderId(incoming.getOrderId());
					existing.setProductId(incoming.getProductId());
					existing.setQuantity(incoming.getQuantity());
					existing.setUnitPrice(incoming.getUnitPrice());
					existing.setLineTotal(incoming.getLineTotal());
					existing.setSelectedOptions(incoming.getSelectedOptions());
					existing.setKitchenLineStatus(incoming.getKitchenLineStatus());
					existing.setSettledAmount(incoming.getSettledAmount());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					orderLineItemRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					orderLineItemRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private SyncApplyResult mergePayment(JsonNode payload) {
		Payment incoming = objectMapper.convertValue(payload, Payment.class);
		normalizePaymentDefaults(incoming);
		return paymentRepository.findById(incoming.getId())
				.map(existing -> {
					if (!LwwMerge.incomingWins(incoming, existing)) {
						return SyncApplyResult.SKIPPED;
					}
					existing.setOrderId(incoming.getOrderId());
					existing.setAmount(incoming.getAmount());
					existing.setMethod(incoming.getMethod());
					existing.setPaidAt(incoming.getPaidAt());
					existing.setExternalReference(incoming.getExternalReference());
					existing.setTipAmount(incoming.getTipAmount());
					existing.setAllocationKind(incoming.getAllocationKind());
					existing.setAllocationDetailsJson(incoming.getAllocationDetailsJson());
					existing.setIsDeleted(incoming.getIsDeleted());
					existing.setCreatedAt(incoming.getCreatedAt());
					existing.setUpdatedAt(incoming.getUpdatedAt());
					paymentRepository.save(existing);
					return SyncApplyResult.APPLIED;
				})
				.orElseGet(() -> {
					paymentRepository.save(incoming);
					return SyncApplyResult.APPLIED;
				});
	}

	private static void normalizePaymentDefaults(Payment p) {
		if (p.getTipAmount() == null) {
			p.setTipAmount(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
		}
		if (p.getAllocationKind() == null) {
			p.setAllocationKind(PaymentAllocationKind.FIXED_AMOUNT);
		}
	}

	private static void normalizeOrderLineItemDefaults(OrderLineItem li) {
		if (li.getSettledAmount() == null) {
			li.setSettledAmount(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
		}
	}
}
