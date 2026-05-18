package com.qr.edge.billing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.entity.TableClosureAuditLog;
import com.qr.common.persistence.entity.TableClosureBalanceDisposition;
import com.qr.common.persistence.entity.TableClosurePolicy;
import com.qr.common.persistence.entity.TableClosureReasonCode;
import com.qr.common.persistence.entity.TableAvailabilityStatus;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.TableClosureAuditLogRepository;
import com.qr.common.security.QrUserPrincipal;
import com.qr.common.security.UserRole;
import com.qr.edge.billing.api.CloseTableSessionRequest;
import com.qr.edge.billing.api.CloseTableSessionResponse;
import com.qr.edge.guest.events.CashierRefreshEvent;
import com.qr.edge.layout.FloorLayoutService;


@Service
public class TableClosureService {

	private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

	private static final Set<OrderStatus> TERMINAL_STATUSES = EnumSet.of(
			OrderStatus.CLOSED,
			OrderStatus.CANCELLED,
			OrderStatus.DRAFT);

	private final Clock clock;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final DiningTableRepository diningTableRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final TableClosureAuditLogRepository tableClosureAuditLogRepository;

	private final FloorLayoutService floorLayoutService;

	private final ApplicationEventPublisher eventPublisher;

	public TableClosureService(
			Clock clock,
			RestaurantOrderRepository restaurantOrderRepository,
			DiningTableRepository diningTableRepository,
			OrderLineItemRepository orderLineItemRepository,
			TableClosureAuditLogRepository tableClosureAuditLogRepository,
			FloorLayoutService floorLayoutService,
			ApplicationEventPublisher eventPublisher) {
		this.clock = clock;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.diningTableRepository = diningTableRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.tableClosureAuditLogRepository = tableClosureAuditLogRepository;
		this.floorLayoutService = floorLayoutService;
		this.eventPublisher = eventPublisher;
	}

	@Transactional
	public void tryReleaseTableIfIdle(UUID restaurantId, UUID tableId) {
		if (tableId == null) {
			return;
		}
		if (restaurantOrderRepository.existsByRestaurantIdAndTableIdAndIsDeletedFalseAndStatusNotIn(
				restaurantId,
				tableId,
				TERMINAL_STATUSES)) {
			return;
		}
		releaseTable(restaurantId, tableId);
	}

	@Transactional
	public CloseTableSessionResponse closeTableSession(UUID restaurantId, UUID tableId) {
		return closeTableSession(restaurantId, tableId, null, null);
	}

	@Transactional
	public CloseTableSessionResponse closeTableSession(
			UUID restaurantId,
			UUID tableId,
			CloseTableSessionRequest request,
			QrUserPrincipal actor) {
		DiningTable table = requireTable(restaurantId, tableId);
		TableClosurePolicy policy = request != null && request.policy() != null
				? request.policy()
				: TableClosurePolicy.STANDARD;
		TableClosureReasonCode reasonCode = request != null && request.reasonCode() != null
				? request.reasonCode()
				: TableClosureReasonCode.PAYMENT_COMPLETE;
		String note = request != null ? trimToNull(request.note()) : null;
		TableClosureBalanceDisposition balanceDisposition = request != null ? request.balanceDisposition() : null;
		validatePolicy(policy, reasonCode, actor);
		List<RestaurantOrder> active = restaurantOrderRepository
				.findByRestaurantIdAndTableIdAndIsDeletedFalseAndStatusNotInOrderByOrderedAtDesc(
						restaurantId,
						tableId,
						TERMINAL_STATUSES);
		LocalDateTime now = LocalDateTime.now(clock);
		List<UUID> closedOrderIds = new ArrayList<>();
		List<UUID> auditLogIds = new ArrayList<>();
		BigDecimal totalRemaining = ZERO;
		for (RestaurantOrder order : active) {
			BigDecimal remaining = remainingPrincipal(order.getId());
			totalRemaining = totalRemaining.add(remaining).setScale(2, RoundingMode.HALF_UP);
			if (remaining.compareTo(ZERO) > 0 && policy == TableClosurePolicy.STANDARD) {
				String label = order.getOrderNumber() != null ? order.getOrderNumber() : order.getId().toString();
				throw new ResponseStatusException(
						HttpStatus.BAD_REQUEST,
						"Adisyon " + label + " için kalan bakiye: " + remaining);
			}
			if (policy == TableClosurePolicy.FORCE_CLOSE_UNPAID && remaining.compareTo(ZERO) > 0) {
				validateBalanceDisposition(balanceDisposition);
			} else if (balanceDisposition != null) {
				throw new ResponseStatusException(
						HttpStatus.BAD_REQUEST,
						"balanceDisposition is only allowed for force close with remaining balance");
			}
			if (order.getStatus() != OrderStatus.CLOSED) {
				order.setStatus(OrderStatus.CLOSED);
				order.setUpdatedAt(now);
				restaurantOrderRepository.save(order);
				closedOrderIds.add(order.getId());
			}
			TableClosureAuditLog audit = new TableClosureAuditLog();
			audit.setRestaurantId(restaurantId);
			audit.setTableId(tableId);
			audit.setOrderId(order.getId());
			audit.setPolicy(policy);
			audit.setReasonCode(reasonCode);
			audit.setActorUserId(actor != null ? actor.userId() : null);
			audit.setActorRole(actor != null && actor.role() != null ? actor.role().name() : null);
			audit.setRemainingPrincipal(remaining);
			audit.setBalanceDisposition(
					remaining.compareTo(ZERO) > 0 && policy == TableClosurePolicy.FORCE_CLOSE_UNPAID
							? balanceDisposition
							: null);
			audit.setClosedAt(now);
			audit.setNote(note);
			TableClosureAuditLog savedAudit = tableClosureAuditLogRepository.save(audit);
			auditLogIds.add(savedAudit.getId());
		}
		boolean released = false;
		if (!restaurantOrderRepository.existsByRestaurantIdAndTableIdAndIsDeletedFalseAndStatusNotIn(
				restaurantId,
				tableId,
				TERMINAL_STATUSES)) {
			releaseTable(restaurantId, tableId);
			released = true;
		}
		eventPublisher.publishEvent(new CashierRefreshEvent(restaurantId));
		return new CloseTableSessionResponse(
				table.getId(),
				table.getLabel(),
				closedOrderIds,
				released,
				policy,
				totalRemaining,
				auditLogIds);
	}

	private static void validateBalanceDisposition(TableClosureBalanceDisposition balanceDisposition) {
		if (balanceDisposition == null) {
			throw new ResponseStatusException(
					HttpStatus.BAD_REQUEST,
					"balanceDisposition (VOID or WRITE_OFF) required when force closing with remaining balance");
		}
	}

	private void validatePolicy(
			TableClosurePolicy policy,
			TableClosureReasonCode reasonCode,
			QrUserPrincipal actor) {
		if (policy == TableClosurePolicy.STANDARD) {
			return;
		}
		if (reasonCode == TableClosureReasonCode.PAYMENT_COMPLETE) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Force close requires a non-payment reason");
		}
		if (actor == null || actor.role() != UserRole.RESTAURANT_ADMIN) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only restaurant admin can force close unpaid tables");
		}
	}

	private void releaseTable(UUID restaurantId, UUID tableId) {
		DiningTable table = requireTable(restaurantId, tableId);
		if (table.getAvailabilityStatus() == TableAvailabilityStatus.EMPTY) {
			return;
		}
		floorLayoutService.updateAvailability(restaurantId, tableId, TableAvailabilityStatus.EMPTY);
	}

	private BigDecimal remainingPrincipal(UUID orderId) {
		BigDecimal remaining = orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(orderId).stream()
				.filter(li -> !Boolean.TRUE.equals(li.getIsDeleted()))
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

	private DiningTable requireTable(UUID restaurantId, UUID tableId) {
		return diningTableRepository.findById(tableId)
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.filter(t -> t.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
	}

	private static String trimToNull(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		return value.trim();
	}
}
