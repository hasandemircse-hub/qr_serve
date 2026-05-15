package com.qr.edge.kitchen;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.kitchen.api.KitchenQueueLineRow;
import com.qr.edge.kitchen.api.KitchenQueuePayload;


@Service
public class KitchenQueueService {

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final DiningTableRepository diningTableRepository;

	private final ProductRepository productRepository;

	public KitchenQueueService(
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			DiningTableRepository diningTableRepository,
			ProductRepository productRepository) {
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.diningTableRepository = diningTableRepository;
		this.productRepository = productRepository;
	}

	public KitchenQueuePayload buildQueue(UUID restaurantId) {
		List<RestaurantOrder> orders = restaurantOrderRepository
				.findByRestaurantIdAndStatusOrderByOrderedAtDesc(restaurantId, OrderStatus.OPEN);
		List<KitchenQueueLineRow> rows = new ArrayList<>();
		for (RestaurantOrder o : orders) {
			if (Boolean.TRUE.equals(o.getIsDeleted())) {
				continue;
			}
			String tableLabel = resolveTableLabel(o.getTableId());
			String channel = o.getNotes() != null && !o.getNotes().isBlank() ? o.getNotes().trim() : "QR";
			orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(o.getId()).forEach(line -> {
				if (Boolean.TRUE.equals(line.getIsDeleted())) {
					return;
				}
				String productName = productRepository.findById(line.getProductId())
						.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
						.map(p -> p.getName())
						.orElse("-");
				rows.add(new KitchenQueueLineRow(
						o.getId(),
						o.getOrderNumber() != null ? o.getOrderNumber() : "",
						tableLabel,
						channel,
						o.getOrderedAt(),
						line.getId(),
						productName,
						line.getQuantity(),
						line.getKitchenLineStatus()));
			});
		}
		return new KitchenQueuePayload(rows);
	}

	private String resolveTableLabel(UUID tableId) {
		if (tableId == null) {
			return "-";
		}
		return diningTableRepository.findById(tableId)
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.map(t -> t.getLabel())
				.orElse("-");
	}
}
