package com.qr.edge.cashier;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.billing.BillingPaymentService;
import com.qr.edge.billing.api.BillingSummaryResponse;
import com.qr.edge.cashier.api.CashierOpenOrderRow;
import com.qr.edge.cashier.api.CashierOpenOrdersResponse;


@Service
public class CashierOpenOrdersService {

	private static final EnumSet<OrderStatus> EXCLUDED = EnumSet.of(OrderStatus.CLOSED, OrderStatus.CANCELLED, OrderStatus.DRAFT);

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final DiningTableRepository diningTableRepository;

	private final BillingPaymentService billingPaymentService;

	public CashierOpenOrdersService(
			RestaurantOrderRepository restaurantOrderRepository,
			DiningTableRepository diningTableRepository,
			BillingPaymentService billingPaymentService) {
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.diningTableRepository = diningTableRepository;
		this.billingPaymentService = billingPaymentService;
	}

	public CashierOpenOrdersResponse listOpenWithBalance(UUID restaurantId) {
		List<RestaurantOrder> candidates = restaurantOrderRepository
				.findByRestaurantIdAndIsDeletedFalseAndStatusNotInOrderByOrderedAtDesc(restaurantId, EXCLUDED);
		List<CashierOpenOrderRow> rows = new ArrayList<>();
		for (RestaurantOrder o : candidates) {
			BillingSummaryResponse s = billingPaymentService.getSummary(restaurantId, o.getId());
			if (s.remainingPrincipal().compareTo(BigDecimal.ZERO) <= 0) {
				continue;
			}
			String tableLabel = resolveTableLabel(o.getTableId());
			rows.add(new CashierOpenOrderRow(
					o.getId(),
					s.orderNumber() != null ? s.orderNumber() : "",
					o.getTableId(),
					tableLabel,
					o.getStatus(),
					s.orderTotal(),
					s.remainingPrincipal(),
					s.lines().size()));
		}
		return new CashierOpenOrdersResponse(rows);
	}

	private String resolveTableLabel(UUID tableId) {
		if (tableId == null) {
			return "-";
		}
		return diningTableRepository.findById(tableId)
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.map(DiningTable::getLabel)
				.orElse("-");
	}
}
