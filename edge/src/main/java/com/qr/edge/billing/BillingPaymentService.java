package com.qr.edge.billing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.billing.fiscal.FiscalSalesDocumentRequest.FiscalLineSnapshot;
import com.qr.common.billing.pos.PosPaymentIntent;
import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.Payment;
import com.qr.common.persistence.entity.PaymentAllocationKind;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.PaymentRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.edge.billing.api.BillingPaymentResponse;
import com.qr.edge.billing.api.BillingSummaryResponse;
import com.qr.edge.billing.api.BillingSummaryResponse.LineSummary;
import com.qr.edge.billing.api.BillingSummaryResponse.PaymentSummary;
import com.qr.edge.billing.api.ProcessPaymentRequest;
import com.qr.edge.billing.api.ProcessPaymentRequest.LinePayRequest;
import com.qr.edge.billing.fiscal.FiscalComplianceService;
import com.qr.edge.print.ThermalEscPosPrintService;
import com.qr.edge.print.billing.AdisyonSlipModel;
import com.qr.edge.print.billing.AdisyonSlipModel.LineEntry;
import com.qr.common.billing.pos.PosTerminalGateway;


@Service
public class BillingPaymentService {

	private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final PaymentRepository paymentRepository;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final ProductRepository productRepository;

	private final FiscalComplianceService fiscalComplianceService;

	private final PosTerminalGateway posTerminalGateway;

	private final ThermalEscPosPrintService thermalEscPosPrintService;

	private final ObjectMapper objectMapper;

	private final java.time.Clock clock;

	public BillingPaymentService(
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			PaymentRepository paymentRepository,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			ProductRepository productRepository,
			FiscalComplianceService fiscalComplianceService,
			PosTerminalGateway posTerminalGateway,
			ThermalEscPosPrintService thermalEscPosPrintService,
			ObjectMapper objectMapper,
			java.time.Clock clock) {
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.paymentRepository = paymentRepository;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.productRepository = productRepository;
		this.fiscalComplianceService = fiscalComplianceService;
		this.posTerminalGateway = posTerminalGateway;
		this.thermalEscPosPrintService = thermalEscPosPrintService;
		this.objectMapper = objectMapper;
		this.clock = clock;
	}

	@Transactional(readOnly = true)
	public BillingSummaryResponse getSummary(UUID restaurantId, UUID orderId) {
		RestaurantOrder order = loadOrder(restaurantId, orderId);
		List<OrderLineItem> lines = loadActiveLines(orderId);
		List<Payment> payments = paymentRepository.findByOrderIdAndIsDeletedFalseOrderByPaidAtAsc(orderId);
		BigDecimal orderTotal = sumLineTotals(lines);
		BigDecimal principalPaid = sumPrincipalPayments(payments);
		BigDecimal remaining = orderTotal.subtract(principalPaid).setScale(2, RoundingMode.HALF_UP);
		if (remaining.compareTo(ZERO) < 0) {
			remaining = ZERO;
		}
		return new BillingSummaryResponse(
				order.getId(),
				order.getOrderNumber(),
				order.getStatus(),
				orderTotal,
				principalPaid,
				remaining,
				toLineSummaries(lines),
				toPaymentSummaries(payments));
	}

	@Transactional
	public BillingPaymentResponse pay(UUID restaurantId, UUID orderId, ProcessPaymentRequest req) {
		RestaurantOrder order = loadOrder(restaurantId, orderId);
		assertPayable(order.getStatus());
		List<OrderLineItem> lines = loadActiveLines(orderId);
		lines.sort(Comparator.comparing(OrderLineItem::getCreatedAt));
		BigDecimal orderTotal = sumLineTotals(lines);
		List<Payment> prior = paymentRepository.findByOrderIdAndIsDeletedFalseOrderByPaidAtAsc(orderId);
		BigDecimal principalPaidBefore = sumPrincipalPayments(prior);
		BigDecimal remainingBefore = orderTotal.subtract(principalPaidBefore).setScale(2, RoundingMode.HALF_UP);
		if (remainingBefore.compareTo(ZERO) <= 0) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order already fully settled");
		}
		BigDecimal tip = req.tipAmount() == null ? ZERO : req.tipAmount().setScale(2, RoundingMode.HALF_UP);
		if (tip.compareTo(ZERO) < 0) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tip cannot be negative");
		}
		List<PrincipalAllocation> allocations;
		BigDecimal principal;
		switch (req.mode()) {
			case REMAINDER -> {
				principal = remainingBefore;
				allocations = fifoAllocate(principal, lines);
			}
			case FIXED_AMOUNT -> {
				if (req.fixedAmount() == null || req.fixedAmount().compareTo(ZERO) <= 0) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "fixedAmount required");
				}
				principal = req.fixedAmount().setScale(2, RoundingMode.HALF_UP);
				if (principal.compareTo(remainingBefore) > 0) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Amount exceeds remaining balance");
				}
				allocations = fifoAllocate(principal, lines);
			}
			case PRODUCT_LINES -> {
				List<LinePayRequest> lp = req.linePayments() == null ? List.of() : req.linePayments();
				if (lp.isEmpty()) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "linePayments required");
				}
				allocations = allocateProductLines(lp, lines);
				principal = allocations.stream().map(PrincipalAllocation::amount).reduce(ZERO, BigDecimal::add)
						.setScale(2, RoundingMode.HALF_UP);
				if (principal.compareTo(ZERO) <= 0) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No principal to pay");
				}
				if (principal.compareTo(remainingBefore) > 0) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Line payments exceed remaining balance");
				}
			}
			default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported payment mode");
		}
		applyAllocationsToLines(lines, allocations);
		for (OrderLineItem li : lines) {
			orderLineItemRepository.save(li);
		}
		Payment payment = new Payment();
		payment.setOrderId(orderId);
		payment.setAmount(principal);
		payment.setTipAmount(tip);
		payment.setMethod(req.method());
		payment.setPaidAt(LocalDateTime.now(clock));
		payment.setExternalReference(req.externalReference());
		payment.setAllocationKind(req.mode());
		try {
			payment.setAllocationDetailsJson(buildAllocationJson(allocations));
		} catch (JsonProcessingException e) {
			throw new IllegalStateException(e);
		}
		paymentRepository.save(payment);
		BigDecimal principalPaidAfter = principalPaidBefore.add(principal).setScale(2, RoundingMode.HALF_UP);
		BigDecimal remainingAfter = orderTotal.subtract(principalPaidAfter).setScale(2, RoundingMode.HALF_UP);
		if (remainingAfter.compareTo(ZERO) <= 0) {
			order.setStatus(OrderStatus.CLOSED);
		}
		restaurantOrderRepository.save(order);
		String allocationJson = payment.getAllocationDetailsJson();
		List<FiscalLineSnapshot> fiscalLines = buildFiscalSnapshots(lines, allocations);
		fiscalComplianceService.recordAdisyonAttempt(restaurantId, order, payment, fiscalLines, allocationJson);
		try {
			Map<String, Object> ext = new LinkedHashMap<>();
			ext.put("allocationDetails", allocationJson);
			posTerminalGateway.notifyPayment(new PosPaymentIntent(
					restaurantId,
					orderId,
					payment.getId(),
					req.method().name(),
					principal,
					tip,
					req.mode().name(),
					ext));
		} catch (RuntimeException ex) {
			// POS hatası ödemeyi geri almaz; operasyonel log
		}
		if (req.printToPrinterId() != null && !req.printToPrinterId().isBlank()) {
			try {
				printReceipt(
						req.printToPrinterId(),
						restaurantId,
						order,
						lines,
						payment,
						principal,
						tip,
						remainingAfter,
						allocations);
			} catch (Exception ex) {
				// yazıcı hatası ödemeyi iptal etmez
			}
		}
		return new BillingPaymentResponse(payment.getId(), principal, tip, remainingAfter, order.getStatus());
	}

	private void printReceipt(
			String printerId,
			UUID restaurantId,
			RestaurantOrder order,
			List<OrderLineItem> lines,
			Payment payment,
			BigDecimal principal,
			BigDecimal tip,
			BigDecimal remainingAfter,
			List<PrincipalAllocation> allocations) throws Exception {
		Restaurant r = restaurantRepository.findById(restaurantId).orElseThrow();
		String tableLabel = "";
		if (order.getTableId() != null) {
			tableLabel = diningTableRepository.findById(order.getTableId()).map(DiningTable::getLabel).orElse("");
		}
		Map<UUID, BigDecimal> portion = allocations.stream()
				.collect(Collectors.toMap(PrincipalAllocation::lineId, PrincipalAllocation::amount, BigDecimal::add));
		List<LineEntry> slipLines = new ArrayList<>();
		for (OrderLineItem li : lines) {
			if (Boolean.TRUE.equals(li.getIsDeleted())) {
				continue;
			}
			String title = productRepository.findById(li.getProductId()).map(Product::getName).orElse("?");
			slipLines.add(new LineEntry(
					title,
					li.getQuantity(),
					li.getLineTotal(),
					portion.getOrDefault(li.getId(), ZERO)));
		}
		BigDecimal orderTotal = sumLineTotals(lines);
		AdisyonSlipModel model = new AdisyonSlipModel(
				r.getName(),
				order.getOrderNumber() != null ? order.getOrderNumber() : order.getId().toString(),
				tableLabel,
				slipLines,
				orderTotal,
				principal,
				tip,
				remainingAfter,
				payment.getMethod().name(),
				"QuickServe");
		byte[] bytes = thermalEscPosPrintService.buildAdisyon(model);
		thermalEscPosPrintService.sendToPrinter(printerId, bytes);
	}

	private record PrincipalAllocation(UUID lineId, BigDecimal amount) {
	}

	private String buildAllocationJson(List<PrincipalAllocation> allocations) throws JsonProcessingException {
		List<Map<String, String>> rows = new ArrayList<>();
		for (PrincipalAllocation pa : allocations) {
			Map<String, String> row = new LinkedHashMap<>();
			row.put("lineItemId", pa.lineId().toString());
			row.put("amount", pa.amount().toPlainString());
			rows.add(row);
		}
		return objectMapper.writeValueAsString(Map.of("principalAllocations", rows));
	}

	private List<PrincipalAllocation> fifoAllocate(BigDecimal principal, List<OrderLineItem> lines) {
		BigDecimal left = principal.setScale(2, RoundingMode.HALF_UP);
		List<PrincipalAllocation> out = new ArrayList<>();
		for (OrderLineItem line : lines) {
			if (Boolean.TRUE.equals(line.getIsDeleted())) {
				continue;
			}
			BigDecimal rem = line.getLineTotal().subtract(nullSafeSettled(line)).setScale(2, RoundingMode.HALF_UP);
			if (rem.compareTo(ZERO) <= 0) {
				continue;
			}
			BigDecimal take = rem.min(left).setScale(2, RoundingMode.HALF_UP);
			if (take.compareTo(ZERO) > 0) {
				out.add(new PrincipalAllocation(line.getId(), take));
				left = left.subtract(take).setScale(2, RoundingMode.HALF_UP);
			}
			if (left.compareTo(ZERO) <= 0) {
				break;
			}
		}
		if (left.compareTo(ZERO) > 0) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot allocate principal to lines");
		}
		return out;
	}

	private List<PrincipalAllocation> allocateProductLines(List<LinePayRequest> requests, List<OrderLineItem> lines) {
		Map<UUID, OrderLineItem> byId = lines.stream().filter(li -> !Boolean.TRUE.equals(li.getIsDeleted()))
				.collect(Collectors.toMap(OrderLineItem::getId, li -> li));
		List<PrincipalAllocation> out = new ArrayList<>();
		for (LinePayRequest linePay : requests) {
			OrderLineItem line = byId.get(linePay.lineItemId());
			if (line == null) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown line: " + linePay.lineItemId());
			}
			BigDecimal rem = line.getLineTotal().subtract(nullSafeSettled(line)).setScale(2, RoundingMode.HALF_UP);
			if (rem.compareTo(ZERO) <= 0) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Line already settled: " + linePay.lineItemId());
			}
			BigDecimal take = linePay.amount() == null ? rem
					: linePay.amount().setScale(2, RoundingMode.HALF_UP);
			if (take.compareTo(ZERO) <= 0) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid line amount");
			}
			if (take.compareTo(rem) > 0) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Line amount exceeds remaining");
			}
			out.add(new PrincipalAllocation(line.getId(), take));
		}
		return out;
	}

	private void applyAllocationsToLines(List<OrderLineItem> lines, List<PrincipalAllocation> allocations) {
		Map<UUID, BigDecimal> delta = allocations.stream()
				.collect(Collectors.toMap(PrincipalAllocation::lineId, PrincipalAllocation::amount, BigDecimal::add));
		for (OrderLineItem li : lines) {
			BigDecimal d = delta.get(li.getId());
			if (d == null) {
				continue;
			}
			li.setSettledAmount(nullSafeSettled(li).add(d).setScale(2, RoundingMode.HALF_UP));
		}
	}

	private List<FiscalLineSnapshot> buildFiscalSnapshots(List<OrderLineItem> lines, List<PrincipalAllocation> allocations) {
		Map<UUID, BigDecimal> portion = allocations.stream()
				.collect(Collectors.toMap(PrincipalAllocation::lineId, PrincipalAllocation::amount, BigDecimal::add));
		List<FiscalLineSnapshot> snaps = new ArrayList<>();
		for (OrderLineItem li : lines) {
			if (Boolean.TRUE.equals(li.getIsDeleted())) {
				continue;
			}
			String name = productRepository.findById(li.getProductId()).map(Product::getName).orElse("?");
			snaps.add(new FiscalLineSnapshot(
					li.getId(),
					name,
					li.getQuantity(),
					li.getLineTotal(),
					portion.getOrDefault(li.getId(), ZERO)));
		}
		return snaps;
	}

	private RestaurantOrder loadOrder(UUID restaurantId, UUID orderId) {
		return restaurantOrderRepository.findByIdAndRestaurantId(orderId, restaurantId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
	}

	private List<OrderLineItem> loadActiveLines(UUID orderId) {
		return orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(orderId).stream()
				.filter(li -> !Boolean.TRUE.equals(li.getIsDeleted()))
				.collect(Collectors.toList());
	}

	private static void assertPayable(OrderStatus status) {
		switch (status) {
			case OPEN, IN_PROGRESS, READY, SERVED -> {
			}
			default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Order not payable in status " + status);
		}
	}

	private static BigDecimal sumLineTotals(List<OrderLineItem> lines) {
		return lines.stream()
				.filter(li -> !Boolean.TRUE.equals(li.getIsDeleted()))
				.map(OrderLineItem::getLineTotal)
				.reduce(ZERO, BigDecimal::add)
				.setScale(2, RoundingMode.HALF_UP);
	}

	private static BigDecimal sumPrincipalPayments(List<Payment> payments) {
		return payments.stream()
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.map(Payment::getAmount)
				.reduce(ZERO, BigDecimal::add)
				.setScale(2, RoundingMode.HALF_UP);
	}

	private List<LineSummary> toLineSummaries(List<OrderLineItem> lines) {
		List<LineSummary> out = new ArrayList<>();
		for (OrderLineItem li : lines) {
			if (Boolean.TRUE.equals(li.getIsDeleted())) {
				continue;
			}
			String name = productRepository.findById(li.getProductId()).map(Product::getName).orElse("?");
			BigDecimal settled = nullSafeSettled(li);
			BigDecimal rem = li.getLineTotal().subtract(settled).setScale(2, RoundingMode.HALF_UP);
			out.add(new LineSummary(li.getId(), name, li.getQuantity(), li.getLineTotal(), settled, rem));
		}
		return out;
	}

	private static List<PaymentSummary> toPaymentSummaries(List<Payment> payments) {
		return payments.stream()
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.map(p -> new PaymentSummary(
						p.getId(),
						p.getAmount(),
						p.getTipAmount() != null ? p.getTipAmount() : ZERO,
						p.getMethod(),
						p.getAllocationKind() != null ? p.getAllocationKind() : PaymentAllocationKind.FIXED_AMOUNT,
						p.getPaidAt()))
				.toList();
	}

	private static BigDecimal nullSafeSettled(OrderLineItem li) {
		if (li.getSettledAmount() == null) {
			return ZERO;
		}
		return li.getSettledAmount().setScale(2, RoundingMode.HALF_UP);
	}
}
