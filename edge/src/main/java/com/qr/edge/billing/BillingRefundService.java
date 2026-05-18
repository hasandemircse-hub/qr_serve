package com.qr.edge.billing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.Payment;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.PaymentRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.billing.api.BillingRefundResponse;
import com.qr.edge.billing.api.RefundPaymentRequest;
import com.qr.edge.guest.events.CashierRefreshEvent;

@Service
public class BillingRefundService {

	private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final PaymentRepository paymentRepository;

	private final ObjectMapper objectMapper;

	private final java.time.Clock clock;

	private final ApplicationEventPublisher eventPublisher;

	public BillingRefundService(
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			PaymentRepository paymentRepository,
			ObjectMapper objectMapper,
			java.time.Clock clock,
			ApplicationEventPublisher eventPublisher) {
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.paymentRepository = paymentRepository;
		this.objectMapper = objectMapper;
		this.clock = clock;
		this.eventPublisher = eventPublisher;
	}

	@Transactional
	public BillingRefundResponse refund(
			UUID restaurantId,
			UUID orderId,
			UUID paymentId,
			RefundPaymentRequest request) {
		RestaurantOrder order = restaurantOrderRepository.findByIdAndRestaurantId(orderId, restaurantId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
		Payment payment = paymentRepository.findById(paymentId)
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.filter(p -> orderId.equals(p.getOrderId()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payment not found"));
		List<OrderLineItem> lines = orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(orderId).stream()
				.filter(li -> !Boolean.TRUE.equals(li.getIsDeleted()))
				.collect(Collectors.toList());
		reverseAllocations(lines, payment);
		for (OrderLineItem li : lines) {
			orderLineItemRepository.save(li);
		}
		LocalDateTime now = LocalDateTime.now(clock);
		payment.setIsDeleted(true);
		payment.setUpdatedAt(now);
		if (request != null && request.note() != null && !request.note().isBlank()) {
			String ref = payment.getExternalReference();
			String note = request.note().trim();
			payment.setExternalReference(
					ref == null || ref.isBlank() ? "REFUND:" + note : ref + " | REFUND:" + note);
		}
		paymentRepository.save(payment);
		BigDecimal remaining = computeRemaining(lines);
		if (remaining.compareTo(ZERO) > 0 && order.getStatus() == OrderStatus.CLOSED) {
			order.setStatus(OrderStatus.OPEN);
			order.setUpdatedAt(now);
			restaurantOrderRepository.save(order);
		}
		eventPublisher.publishEvent(new CashierRefreshEvent(restaurantId));
		return new BillingRefundResponse(
				payment.getId(),
				payment.getAmount(),
				payment.getTipAmount() != null ? payment.getTipAmount() : ZERO,
				remaining,
				order.getStatus());
	}

	private void reverseAllocations(List<OrderLineItem> lines, Payment payment) {
		List<AllocationRow> rows = parseAllocations(payment.getAllocationDetailsJson());
		if (rows.isEmpty()) {
			BigDecimal left = payment.getAmount();
			for (OrderLineItem line : lines) {
				if (left.compareTo(ZERO) <= 0) {
					break;
				}
				BigDecimal settled = nullSafeSettled(line);
				BigDecimal take = settled.min(left).setScale(2, RoundingMode.HALF_UP);
				if (take.compareTo(ZERO) > 0) {
					line.setSettledAmount(settled.subtract(take).setScale(2, RoundingMode.HALF_UP));
					left = left.subtract(take).setScale(2, RoundingMode.HALF_UP);
				}
			}
			return;
		}
		Map<UUID, OrderLineItem> byId = lines.stream().collect(Collectors.toMap(OrderLineItem::getId, li -> li));
		for (AllocationRow row : rows) {
			OrderLineItem line = byId.get(row.lineItemId());
			if (line == null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Allocation line not found on order");
			}
			BigDecimal settled = nullSafeSettled(line);
			if (row.amount().compareTo(settled) > 0) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot refund more than settled on line");
			}
			line.setSettledAmount(settled.subtract(row.amount()).setScale(2, RoundingMode.HALF_UP));
		}
	}

	private List<AllocationRow> parseAllocations(String json) {
		if (json == null || json.isBlank()) {
			return List.of();
		}
		try {
			Map<String, Object> root = objectMapper.readValue(json, new TypeReference<>() {
			});
			Object raw = root.get("principalAllocations");
			if (!(raw instanceof List<?> list)) {
				return List.of();
			}
			List<AllocationRow> rows = new ArrayList<>();
			for (Object item : list) {
				if (!(item instanceof Map<?, ?> map)) {
					continue;
				}
				Object lineId = map.get("lineItemId");
				Object amount = map.get("amount");
				if (lineId == null || amount == null) {
					continue;
				}
				rows.add(new AllocationRow(UUID.fromString(lineId.toString()), new BigDecimal(amount.toString())));
			}
			return rows;
		} catch (Exception e) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid payment allocation details");
		}
	}

	private BigDecimal computeRemaining(List<OrderLineItem> lines) {
		BigDecimal remaining = lines.stream()
				.map(li -> li.getLineTotal().subtract(nullSafeSettled(li)).setScale(2, RoundingMode.HALF_UP))
				.filter(rem -> rem.compareTo(ZERO) > 0)
				.reduce(ZERO, BigDecimal::add)
				.setScale(2, RoundingMode.HALF_UP);
		return remaining.compareTo(ZERO) < 0 ? ZERO : remaining;
	}

	private static BigDecimal nullSafeSettled(OrderLineItem li) {
		if (li.getSettledAmount() == null) {
			return ZERO;
		}
		return li.getSettledAmount().setScale(2, RoundingMode.HALF_UP);
	}

	private record AllocationRow(UUID lineItemId, BigDecimal amount) {
	}
}
