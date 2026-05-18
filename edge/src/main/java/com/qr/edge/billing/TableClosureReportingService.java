package com.qr.edge.billing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.entity.TableClosureAuditLog;
import com.qr.common.persistence.entity.TableClosurePolicy;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.TableClosureAuditLogRepository;
import com.qr.edge.billing.api.BillingSummaryResponse;
import com.qr.edge.billing.api.ClosureAuditRow;
import com.qr.edge.billing.api.ClosureBalanceReportResponse;
import com.qr.edge.billing.api.DeferredOrderRow;

@Service
public class TableClosureReportingService {

	private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

	private static final int MAX_AUDIT_ROWS = 200;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final DiningTableRepository diningTableRepository;

	private final TableClosureAuditLogRepository tableClosureAuditLogRepository;

	private final BillingPaymentService billingPaymentService;

	public TableClosureReportingService(
			RestaurantOrderRepository restaurantOrderRepository,
			DiningTableRepository diningTableRepository,
			TableClosureAuditLogRepository tableClosureAuditLogRepository,
			BillingPaymentService billingPaymentService) {
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.diningTableRepository = diningTableRepository;
		this.tableClosureAuditLogRepository = tableClosureAuditLogRepository;
		this.billingPaymentService = billingPaymentService;
	}

	@Transactional(readOnly = true)
	public ClosureBalanceReportResponse buildReport(UUID restaurantId) {
		List<DeferredOrderRow> deferred = listDeferredWithBalance(restaurantId);
		BigDecimal totalDeferred = deferred.stream()
				.map(DeferredOrderRow::remainingPrincipal)
				.reduce(ZERO, BigDecimal::add)
				.setScale(2, RoundingMode.HALF_UP);
		List<ClosureAuditRow> audits = listExceptionClosures(restaurantId);
		return new ClosureBalanceReportResponse(totalDeferred, deferred, audits);
	}

	private List<DeferredOrderRow> listDeferredWithBalance(UUID restaurantId) {
		List<RestaurantOrder> orders = restaurantOrderRepository
				.findByRestaurantIdAndStatusOrderByOrderedAtDesc(restaurantId, OrderStatus.DEFERRED)
				.stream()
				.filter(o -> !Boolean.TRUE.equals(o.getIsDeleted()))
				.toList();
		List<DeferredOrderRow> rows = new ArrayList<>();
		for (RestaurantOrder order : orders) {
			BillingSummaryResponse summary = billingPaymentService.getSummary(restaurantId, order.getId());
			if (summary.remainingPrincipal().compareTo(ZERO) <= 0) {
				continue;
			}
			rows.add(new DeferredOrderRow(
					order.getId(),
					order.getOrderNumber() != null ? order.getOrderNumber() : "",
					order.getStatus(),
					order.getTableId(),
					resolveTableLabel(order.getTableId()),
					summary.remainingPrincipal(),
					order.getOrderedAt()));
		}
		return rows;
	}

	private List<ClosureAuditRow> listExceptionClosures(UUID restaurantId) {
		List<TableClosureAuditLog> logs = tableClosureAuditLogRepository
				.findByRestaurantIdAndIsDeletedFalseOrderByClosedAtDesc(restaurantId);
		List<ClosureAuditRow> rows = new ArrayList<>();
		for (TableClosureAuditLog log : logs) {
			if (log.getPolicy() == TableClosurePolicy.STANDARD
					&& log.getRemainingPrincipal().compareTo(ZERO) <= 0) {
				continue;
			}
			RestaurantOrder order = restaurantOrderRepository.findById(log.getOrderId()).orElse(null);
			String orderNumber = order != null && order.getOrderNumber() != null ? order.getOrderNumber() : "";
			rows.add(new ClosureAuditRow(
					log.getId(),
					log.getOrderId(),
					orderNumber,
					log.getTableId(),
					resolveTableLabel(log.getTableId()),
					log.getPolicy(),
					log.getReasonCode(),
					log.getBalanceDisposition(),
					log.getRemainingPrincipal(),
					log.getClosedAt(),
					log.getNote(),
					log.getActorRole()));
			if (rows.size() >= MAX_AUDIT_ROWS) {
				break;
			}
		}
		rows.sort(Comparator.comparing(ClosureAuditRow::closedAt).reversed());
		return rows;
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
