package com.qr.edge.admin;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;


@Service
public class OrderSplitService {

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	public OrderSplitService(
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository) {
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
	}

	/**
	 * Hesabı kişilere böler: her alt liste yeni bir açık siparişe taşınan satır kimlikleridir.
	 * Tüm satırlar tam olarak bir kez atanmalıdır.
	 */
	@Transactional
	public List<UUID> splitOrder(UUID restaurantId, UUID orderId, List<List<UUID>> parts) {
		if (parts == null || parts.size() < 2) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "At least two split parts required");
		}
		RestaurantOrder parent = restaurantOrderRepository.findByIdAndRestaurantId(orderId, restaurantId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
		if (parent.getStatus() != OrderStatus.OPEN && parent.getStatus() != OrderStatus.IN_PROGRESS) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order must be OPEN or IN_PROGRESS to split");
		}
		List<OrderLineItem> lines = orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(orderId);
		Set<UUID> all = new HashSet<>();
		for (OrderLineItem li : lines) {
			all.add(li.getId());
		}
		if (all.isEmpty()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order has no lines");
		}
		Set<UUID> assigned = new HashSet<>();
		for (List<UUID> part : parts) {
			if (part == null || part.isEmpty()) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Each part must contain line items");
			}
			for (UUID lineId : part) {
				if (!all.contains(lineId) || !assigned.add(lineId)) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or duplicate line id: " + lineId);
				}
			}
		}
		if (!assigned.equals(all)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "All order lines must be assigned exactly once");
		}

		List<UUID> newOrderIds = new ArrayList<>();
		java.time.LocalDateTime now = java.time.LocalDateTime.now();
		for (List<UUID> part : parts) {
			RestaurantOrder child = new RestaurantOrder();
			child.setRestaurantId(parent.getRestaurantId());
			child.setTableId(parent.getTableId());
			child.setStatus(OrderStatus.OPEN);
			child.setOrderedAt(parent.getOrderedAt());
			child.setNotes("SPLIT_FROM:" + parent.getId());
			child.assignIdIfAbsent();
			restaurantOrderRepository.save(child);
			child.setOrderNumber("SP-" + child.getId().toString().replace("-", "").substring(0, 12).toUpperCase());
			restaurantOrderRepository.save(child);
			newOrderIds.add(child.getId());
			for (UUID lineId : part) {
				OrderLineItem li = orderLineItemRepository.findById(lineId).orElseThrow();
				if (!li.getOrderId().equals(parent.getId())) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Line does not belong to order");
				}
				li.setOrderId(child.getId());
				li.setUpdatedAt(now);
				orderLineItemRepository.save(li);
			}
		}
		parent.setStatus(OrderStatus.CLOSED);
		parent.setNotes("SPLIT_INTO:" + newOrderIds.stream().map(UUID::toString).findFirst().orElse(""));
		parent.setUpdatedAt(now);
		restaurantOrderRepository.save(parent);
		return newOrderIds;
	}
}
