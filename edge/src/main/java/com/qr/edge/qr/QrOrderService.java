package com.qr.edge.qr;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.ProductOption;
import com.qr.common.persistence.entity.ProductOptionGroup;
import com.qr.common.persistence.entity.OptionSelectionType;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.ProductOptionGroupRepository;
import com.qr.common.persistence.repository.ProductOptionRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.edge.guest.events.GuestOrderPlacedEvent;
import com.qr.edge.qr.api.CreateQrOrderRequest;
import com.qr.edge.qr.api.CreateQrOrderRequest.QrOrderLineRequest;
import com.qr.edge.qr.api.CreateQrOrderResponse;


@Service
public class QrOrderService {

	private final Clock clock;

	private final ObjectMapper objectMapper;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final MenuRepository menuRepository;

	private final ProductRepository productRepository;

	private final ProductOptionGroupRepository productOptionGroupRepository;

	private final ProductOptionRepository productOptionRepository;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final ApplicationEventPublisher eventPublisher;

	public QrOrderService(
			Clock clock,
			ObjectMapper objectMapper,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			MenuRepository menuRepository,
			ProductRepository productRepository,
			ProductOptionGroupRepository productOptionGroupRepository,
			ProductOptionRepository productOptionRepository,
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			ApplicationEventPublisher eventPublisher) {
		this.clock = clock;
		this.objectMapper = objectMapper;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.menuRepository = menuRepository;
		this.productRepository = productRepository;
		this.productOptionGroupRepository = productOptionGroupRepository;
		this.productOptionRepository = productOptionRepository;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.eventPublisher = eventPublisher;
	}

	@Transactional
	public CreateQrOrderResponse placeOrder(CreateQrOrderRequest request) {
		if (!restaurantRepository.existsById(request.restaurantId())) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found");
		}
		if (request.tableId() != null
				&& !diningTableRepository.existsByIdAndRestaurantId(request.tableId(), request.restaurantId())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid table for restaurant");
		}
		BigDecimal grandTotal = BigDecimal.ZERO;
		List<UUID> lineIds = new ArrayList<>();
		LocalDateTime now = LocalDateTime.now(clock);

		RestaurantOrder order = new RestaurantOrder();
		order.setRestaurantId(request.restaurantId());
		order.setTableId(request.tableId());
		order.setStatus(OrderStatus.OPEN);
		order.setOrderedAt(now);
		String channel = request.channel() != null && !request.channel().isBlank() ? request.channel().trim() : "QR";
		order.setNotes(channel);
		if (request.guestToken() != null && !request.guestToken().isBlank()) {
			order.setGuestToken(request.guestToken().trim());
		}
		order.assignIdIfAbsent();
		restaurantOrderRepository.save(order);
		order.setOrderNumber("QR-" + order.getId().toString().replace("-", "").substring(0, 12).toUpperCase());
		restaurantOrderRepository.save(order);

		for (QrOrderLineRequest line : request.lines()) {
			Product product = productRepository.findById(line.productId())
					.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
					.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
			Menu menu = menuRepository.findById(product.getMenuId())
					.filter(m -> !Boolean.TRUE.equals(m.getIsDeleted()))
					.orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid menu"));
			if (!menu.getRestaurantId().equals(request.restaurantId())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Product does not belong to restaurant");
			}
			NormalizedOptions normalized = normalizeSelectedOptions(line.selectedOptions(), line.productId());
			BigDecimal unitPrice = product.getPrice().add(normalized.adjustment()).setScale(2, RoundingMode.HALF_UP);
			BigDecimal lineTotal = unitPrice.multiply(BigDecimal.valueOf(line.quantity())).setScale(2, RoundingMode.HALF_UP);
			grandTotal = grandTotal.add(lineTotal);

			OrderLineItem item = new OrderLineItem();
			item.setOrderId(order.getId());
			item.setProductId(product.getId());
			item.setQuantity(line.quantity());
			item.setUnitPrice(unitPrice);
			item.setLineTotal(lineTotal);
			item.setSelectedOptions(normalized.json());
			item.setUpdatedAt(now);
			item.assignIdIfAbsent();
			orderLineItemRepository.save(item);
			lineIds.add(item.getId());
		}

		if (order.getTableId() != null) {
			eventPublisher.publishEvent(new GuestOrderPlacedEvent(order.getId()));
		}

		return new CreateQrOrderResponse(
				order.getId(),
				order.getOrderNumber(),
				lineIds,
				grandTotal.setScale(2, RoundingMode.HALF_UP));
	}

	private NormalizedOptions normalizeSelectedOptions(JsonNode root, UUID productId) {
		if (root == null || !root.isObject()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectedOptions must be an object");
		}
		if (!root.has("schemaVersion") || root.get("schemaVersion").asInt() != 1) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectedOptions.schemaVersion must be 1");
		}
		JsonNode stepsNode = root.get("steps");
		if (stepsNode == null || !stepsNode.isArray()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectedOptions.steps must be an array");
		}
		List<ProductOptionGroup> groups = productOptionGroupRepository
				.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(productId);
		if (groups.isEmpty()) {
			if (stepsNode.size() != 0) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "This product has no option groups; steps must be empty");
			}
			ObjectNode out = objectMapper.createObjectNode();
			out.put("schemaVersion", 1);
			out.set("steps", objectMapper.createArrayNode());
			out.put("optionsTotalAdjustment", 0);
			return new NormalizedOptions(out.toString(), BigDecimal.ZERO);
		}
		Map<UUID, ProductOptionGroup> groupById = new HashMap<>();
		for (ProductOptionGroup g : groups) {
			groupById.put(g.getId(), g);
		}
		Map<UUID, JsonNode> stepByGroup = new LinkedHashMap<>();
		for (JsonNode step : stepsNode) {
			if (!step.hasNonNull("groupId")) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Each step requires groupId");
			}
			UUID gid = UUID.fromString(step.get("groupId").asText());
			if (!groupById.containsKey(gid)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown option group: " + gid);
			}
			if (stepByGroup.putIfAbsent(gid, step) != null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Duplicate step for group: " + gid);
			}
		}
		if (stepByGroup.size() != groups.size()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Each option group must have exactly one step");
		}
		BigDecimal adjustmentSum = BigDecimal.ZERO;
		ArrayNode normalizedSteps = objectMapper.createArrayNode();
		for (ProductOptionGroup group : groups) {
			JsonNode step = stepByGroup.get(group.getId());
			String typeStr = step.hasNonNull("selectionType") ? step.get("selectionType").asText() : "";
			if (!typeStr.equals(group.getSelectionType().name())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectionType mismatch for group " + group.getId());
			}
			JsonNode idsNode = step.get("selectedOptionIds");
			if (idsNode == null || !idsNode.isArray()) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "selectedOptionIds must be an array");
			}
			List<UUID> picked = new ArrayList<>();
			Set<UUID> dedup = new HashSet<>();
			for (JsonNode idNode : idsNode) {
				if (idNode.isNull()) {
					continue;
				}
				UUID oid = UUID.fromString(idNode.asText());
				if (!dedup.add(oid)) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Duplicate option id in step");
				}
				picked.add(oid);
			}
			if (group.getSelectionType() == OptionSelectionType.SINGLE) {
				if (picked.size() != 1) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "SINGLE group requires exactly one option");
				}
			}
			List<ProductOption> allowed = productOptionRepository.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(group.getId());
			Map<UUID, ProductOption> allowedMap = new HashMap<>();
			for (ProductOption o : allowed) {
				allowedMap.put(o.getId(), o);
			}
			for (UUID oid : picked) {
				ProductOption opt = allowedMap.get(oid);
				if (opt == null) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid option for group " + group.getId());
				}
				adjustmentSum = adjustmentSum.add(opt.getPriceAdjustment() != null ? opt.getPriceAdjustment() : BigDecimal.ZERO);
			}
			ObjectNode n = objectMapper.createObjectNode();
			n.put("groupId", group.getId().toString());
			n.put("selectionType", group.getSelectionType().name());
			ArrayNode arr = objectMapper.createArrayNode();
			for (UUID oid : picked) {
				arr.add(oid.toString());
			}
			n.set("selectedOptionIds", arr);
			normalizedSteps.add(n);
		}
		ObjectNode out = objectMapper.createObjectNode();
		out.put("schemaVersion", 1);
		out.set("steps", normalizedSteps);
		out.put("optionsTotalAdjustment", adjustmentSum.doubleValue());
		return new NormalizedOptions(out.toString(), adjustmentSum.setScale(2, RoundingMode.HALF_UP));
	}

	private record NormalizedOptions(String json, BigDecimal adjustment) {
	}
}
