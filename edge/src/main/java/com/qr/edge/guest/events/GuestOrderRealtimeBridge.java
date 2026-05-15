package com.qr.edge.guest.events;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.GuestServiceRequestRepository;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.guest.realtime.GuestMenuSessionRegistry;
import com.qr.edge.guest.realtime.KitchenPushSessionRegistry;
import com.qr.edge.guest.realtime.WaiterPushSessionRegistry;


@Component
public class GuestOrderRealtimeBridge {

	private static final Logger log = LoggerFactory.getLogger(GuestOrderRealtimeBridge.class);

	private final ObjectMapper objectMapper;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final ProductRepository productRepository;

	private final DiningTableRepository diningTableRepository;

	private final KitchenPushSessionRegistry kitchenPushSessionRegistry;

	private final GuestMenuSessionRegistry guestMenuSessionRegistry;

	private final WaiterPushSessionRegistry waiterPushSessionRegistry;

	private final GuestServiceRequestRepository guestServiceRequestRepository;

	public GuestOrderRealtimeBridge(
			ObjectMapper objectMapper,
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			ProductRepository productRepository,
			DiningTableRepository diningTableRepository,
			KitchenPushSessionRegistry kitchenPushSessionRegistry,
			GuestMenuSessionRegistry guestMenuSessionRegistry,
			WaiterPushSessionRegistry waiterPushSessionRegistry,
			GuestServiceRequestRepository guestServiceRequestRepository) {
		this.objectMapper = objectMapper;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.productRepository = productRepository;
		this.diningTableRepository = diningTableRepository;
		this.kitchenPushSessionRegistry = kitchenPushSessionRegistry;
		this.guestMenuSessionRegistry = guestMenuSessionRegistry;
		this.waiterPushSessionRegistry = waiterPushSessionRegistry;
		this.guestServiceRequestRepository = guestServiceRequestRepository;
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	@Async
	public void onGuestOrderPlaced(GuestOrderPlacedEvent event) {
		try {
			RestaurantOrder order = restaurantOrderRepository.findById(event.orderId()).orElse(null);
			if (order == null || order.getTableId() == null) {
				return;
			}
			List<OrderLineItem> lines = orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(order.getId());
			String tableLabel = diningTableRepository.findById(order.getTableId())
					.map(t -> t.getLabel())
					.orElse("-");
			ObjectNode kitchen = objectMapper.createObjectNode();
			kitchen.put("type", "NEW_GUEST_ORDER");
			kitchen.put("orderId", order.getId().toString());
			kitchen.put("orderNumber", order.getOrderNumber());
			kitchen.put("tableLabel", tableLabel);
			kitchen.put("lineCount", lines.size());
			String notes = order.getNotes();
			kitchen.put("orderChannel", notes != null && !notes.isBlank() ? notes : "QR");
			kitchenPushSessionRegistry.broadcast(order.getRestaurantId(), kitchen.toString());

			if (order.getGuestToken() == null || order.getGuestToken().isBlank()) {
				return;
			}
			ObjectNode guest = objectMapper.createObjectNode();
			guest.put("type", "ORDER_CONFIRMED");
			guest.put("orderId", order.getId().toString());
			guest.put("orderNumber", order.getOrderNumber());
			ArrayNode lineArr = objectMapper.createArrayNode();
			for (OrderLineItem line : lines) {
				ObjectNode n = objectMapper.createObjectNode();
				n.put("lineId", line.getId().toString());
				n.put("productId", line.getProductId().toString());
				n.put("productName", productRepository.findById(line.getProductId()).map(p -> p.getName()).orElse("-"));
				n.put("quantity", line.getQuantity());
				n.put("kitchenLineStatus", line.getKitchenLineStatus().name());
				lineArr.add(n);
			}
			guest.set("lines", lineArr);
			guestMenuSessionRegistry.broadcastByToken(
					order.getRestaurantId().toString(),
					order.getTableId().toString(),
					order.getGuestToken(),
					guest.toString());
		} catch (Exception ex) {
			log.warn("Guest order realtime broadcast failed: {}", ex.getMessage());
		}
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	@Async
	public void onKitchenLineGuestNotify(KitchenLineGuestNotifyEvent event) {
		try {
			RestaurantOrder order = restaurantOrderRepository.findById(event.orderId()).orElse(null);
			if (order == null) {
				return;
			}
			OrderLineItem line = orderLineItemRepository.findById(event.lineId()).orElse(null);
			if (line == null || !line.getOrderId().equals(order.getId())) {
				return;
			}
			if (order.getTableId() != null) {
				ObjectNode kitchen = objectMapper.createObjectNode();
				kitchen.put("type", "LINE_KITCHEN_STATUS");
				kitchen.put("orderId", order.getId().toString());
				kitchen.put("orderNumber", order.getOrderNumber() != null ? order.getOrderNumber() : "");
				kitchen.put("lineId", line.getId().toString());
				kitchen.put("kitchenLineStatus", line.getKitchenLineStatus().name());
				kitchenPushSessionRegistry.broadcast(order.getRestaurantId(), kitchen.toString());
			}
			if (order.getGuestToken() == null || order.getGuestToken().isBlank() || order.getTableId() == null) {
				return;
			}
			ObjectNode guest = objectMapper.createObjectNode();
			guest.put("type", "LINE_KITCHEN_STATUS");
			guest.put("orderId", order.getId().toString());
			guest.put("lineId", line.getId().toString());
			guest.put("kitchenLineStatus", line.getKitchenLineStatus().name());
			guestMenuSessionRegistry.broadcastByToken(
					order.getRestaurantId().toString(),
					order.getTableId().toString(),
					order.getGuestToken(),
					guest.toString());
		} catch (Exception ex) {
			log.warn("Guest line status broadcast failed: {}", ex.getMessage());
		}
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	@Async
	public void onGuestServiceRequestPosted(GuestServiceRequestPostedEvent event) {
		try {
			var req = guestServiceRequestRepository.findById(event.requestId()).orElse(null);
			if (req == null) {
				return;
			}
			String tableLabel = diningTableRepository.findById(req.getTableId())
					.map(t -> t.getLabel())
					.orElse("-");
			ObjectNode node = objectMapper.createObjectNode();
			node.put("type", "GUEST_SERVICE_REQUEST");
			node.put("requestId", req.getId().toString());
			node.put("requestType", req.getRequestType().name());
			node.put("tableLabel", tableLabel);
			node.put("tableId", req.getTableId().toString());
			waiterPushSessionRegistry.broadcast(req.getRestaurantId(), node.toString());
		} catch (Exception ex) {
			log.warn("Waiter service request broadcast failed: {}", ex.getMessage());
		}
	}
}
