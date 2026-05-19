package com.qr.edge.kitchen;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.KitchenLineStatus;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.guest.events.KitchenLineGuestNotifyEvent;


@Service
public class KitchenLineService {

	private final Clock clock;

	private final OrderLineItemRepository orderLineItemRepository;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final ApplicationEventPublisher eventPublisher;

	public KitchenLineService(
			Clock clock,
			OrderLineItemRepository orderLineItemRepository,
			RestaurantOrderRepository restaurantOrderRepository,
			ApplicationEventPublisher eventPublisher) {
		this.clock = clock;
		this.orderLineItemRepository = orderLineItemRepository;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.eventPublisher = eventPublisher;
	}

	@Transactional
	public void markLineReceived(UUID restaurantId, UUID orderId, UUID lineId) {
		RestaurantOrder order = restaurantOrderRepository.findByIdAndRestaurantId(orderId, restaurantId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
		OrderLineItem line = orderLineItemRepository.findById(lineId)
				.filter(l -> l.getOrderId().equals(order.getId()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Line not found"));
		if (line.getKitchenLineStatus() == KitchenLineStatus.RECEIVED || line.getKitchenLineStatus() == KitchenLineStatus.READY) {
			return;
		}
		line.setKitchenLineStatus(KitchenLineStatus.RECEIVED);
		line.setUpdatedAt(LocalDateTime.now(clock));
		orderLineItemRepository.save(line);
		eventPublisher.publishEvent(new KitchenLineGuestNotifyEvent(order.getId(), lineId));
	}

	@Transactional
	public void markLineKitchenReady(UUID restaurantId, UUID orderId, UUID lineId) {
		RestaurantOrder order = restaurantOrderRepository.findByIdAndRestaurantId(orderId, restaurantId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
		OrderLineItem line = orderLineItemRepository.findById(lineId)
				.filter(l -> l.getOrderId().equals(order.getId()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Line not found"));
		if (line.getKitchenLineStatus() == KitchenLineStatus.READY) {
			return;
		}
		line.setKitchenLineStatus(KitchenLineStatus.READY);
		line.setUpdatedAt(LocalDateTime.now(clock));
		orderLineItemRepository.save(line);
		eventPublisher.publishEvent(new KitchenLineReadyEvent(order.getId(), lineId));
		eventPublisher.publishEvent(new KitchenLineGuestNotifyEvent(order.getId(), lineId));
	}

	@Transactional
	public void markLineDelivered(UUID restaurantId, UUID orderId, UUID lineId) {
		RestaurantOrder order = restaurantOrderRepository.findByIdAndRestaurantId(orderId, restaurantId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
		OrderLineItem line = orderLineItemRepository.findById(lineId)
				.filter(l -> l.getOrderId().equals(order.getId()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Line not found"));
		if (line.getKitchenLineStatus() != KitchenLineStatus.READY) {
			throw new ResponseStatusException(
					HttpStatus.BAD_REQUEST,
					"Line must be READY before delivery");
		}
		line.setKitchenLineStatus(KitchenLineStatus.DELIVERED);
		line.setUpdatedAt(LocalDateTime.now(clock));
		orderLineItemRepository.save(line);
		eventPublisher.publishEvent(new KitchenLineGuestNotifyEvent(order.getId(), lineId));
		maybeMarkOrderServed(order);
	}

	private void maybeMarkOrderServed(RestaurantOrder order) {
		boolean allDelivered = orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(order.getId()).stream()
				.filter(li -> !Boolean.TRUE.equals(li.getIsDeleted()))
				.allMatch(li -> li.getKitchenLineStatus() == KitchenLineStatus.DELIVERED);
		if (!allDelivered) {
			return;
		}
		if (order.getStatus() == OrderStatus.OPEN
				|| order.getStatus() == OrderStatus.IN_PROGRESS
				|| order.getStatus() == OrderStatus.READY) {
			order.setStatus(OrderStatus.SERVED);
			order.setUpdatedAt(LocalDateTime.now(clock));
			restaurantOrderRepository.save(order);
		}
	}
}
