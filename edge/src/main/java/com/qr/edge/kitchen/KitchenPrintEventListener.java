package com.qr.edge.kitchen;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.print.PrintManager;
import com.qr.edge.print.PrinterStation;
import com.qr.edge.print.config.PrintProperties;
import com.qr.edge.print.config.PrintProperties.PrinterDefinition;
import com.qr.edge.print.template.SlipDocumentRenderer;


@Component
public class KitchenPrintEventListener {

	private static final Logger log = LoggerFactory.getLogger(KitchenPrintEventListener.class);

	private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");

	private final PrintManager printManager;

	private final SlipDocumentRenderer slipDocumentRenderer;

	private final PrintProperties printProperties;

	private final OrderLineItemRepository orderLineItemRepository;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final ProductRepository productRepository;

	private final DiningTableRepository diningTableRepository;

	private final Clock clock;

	public KitchenPrintEventListener(
			PrintManager printManager,
			SlipDocumentRenderer slipDocumentRenderer,
			PrintProperties printProperties,
			OrderLineItemRepository orderLineItemRepository,
			RestaurantOrderRepository restaurantOrderRepository,
			ProductRepository productRepository,
			DiningTableRepository diningTableRepository,
			Clock clock) {
		this.printManager = printManager;
		this.slipDocumentRenderer = slipDocumentRenderer;
		this.printProperties = printProperties;
		this.orderLineItemRepository = orderLineItemRepository;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.productRepository = productRepository;
		this.diningTableRepository = diningTableRepository;
		this.clock = clock;
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	@Async
	public void printKitchenTicketAfterCommit(KitchenLineReadyEvent event) {
		if (!printProperties.isEnabled()) {
			return;
		}
		PrinterDefinition printer = printProperties.getPrinters().stream()
				.filter(p -> p.getStation() == PrinterStation.KITCHEN)
				.findFirst()
				.orElse(null);
		if (printer == null) {
			log.warn("No KITCHEN printer configured; skip print for line {}", event.lineId());
			return;
		}
		try {
			OrderLineItem line = orderLineItemRepository.findById(event.lineId()).orElse(null);
			RestaurantOrder order = restaurantOrderRepository.findById(event.orderId()).orElse(null);
			if (line == null || order == null) {
				log.warn("Order/line missing after commit, skip print");
				return;
			}
			Product product = productRepository.findById(line.getProductId()).orElse(null);
			String productName = product != null ? product.getName() : line.getProductId().toString();
			String tableLabel = "-";
			if (order.getTableId() != null) {
				tableLabel = diningTableRepository.findById(order.getTableId())
						.map(DiningTable::getLabel)
						.orElse(order.getTableId().toString());
			}
			Map<String, String> vars = new LinkedHashMap<>();
			vars.put("orderNumber", order.getOrderNumber() != null ? order.getOrderNumber() : order.getId().toString());
			vars.put("productName", productName);
			vars.put("quantity", String.valueOf(line.getQuantity()));
			vars.put("tableLabel", tableLabel);
			vars.put("orderedAt", LocalDateTime.now(clock).format(TIME));
			byte[] payload = slipDocumentRenderer.render(printer.getTemplate(), vars);
			printManager.enqueue(printer.getId(), payload);
		} catch (Exception ex) {
			log.error("Kitchen slip render/print failed: {}", ex.getMessage());
		}
	}
}
