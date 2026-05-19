package com.qr.edge.waiter;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.security.QrUserPrincipal;
import com.qr.common.persistence.entity.KitchenLineStatus;
import com.qr.edge.guest.GuestMenuService;
import com.qr.edge.guest.api.GuestMenuPayload;
import com.qr.edge.kitchen.KitchenLineService;
import com.qr.edge.kitchen.KitchenQueueService;
import com.qr.edge.kitchen.api.KitchenQueuePayload;
import com.qr.edge.billing.TableOrderTransferService;
import com.qr.edge.qr.QrOrderService;
import com.qr.edge.qr.api.CreateQrOrderRequest;
import com.qr.edge.qr.api.CreateQrOrderResponse;
import com.qr.edge.waiter.api.TransferTableOrdersRequest;
import com.qr.edge.waiter.api.TransferTableOrdersResponse;
import com.qr.edge.waiter.api.WaiterPlaceOrderRequest;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/waiter")
public class WaiterRestController {

	private final DiningTableRepository diningTableRepository;

	private final GuestMenuService guestMenuService;

	private final QrOrderService qrOrderService;

	private final KitchenQueueService kitchenQueueService;

	private final TableOrderTransferService tableOrderTransferService;

	private final KitchenLineService kitchenLineService;

	public WaiterRestController(
			DiningTableRepository diningTableRepository,
			GuestMenuService guestMenuService,
			QrOrderService qrOrderService,
			KitchenQueueService kitchenQueueService,
			TableOrderTransferService tableOrderTransferService,
			KitchenLineService kitchenLineService) {
		this.diningTableRepository = diningTableRepository;
		this.guestMenuService = guestMenuService;
		this.qrOrderService = qrOrderService;
		this.kitchenQueueService = kitchenQueueService;
		this.tableOrderTransferService = tableOrderTransferService;
		this.kitchenLineService = kitchenLineService;
	}

	@GetMapping("/tables")
	@PreAuthorize("hasAnyRole('WAITER','RESTAURANT_ADMIN')")
	public WaiterTablesResponse tables(@AuthenticationPrincipal QrUserPrincipal principal) {
		UUID restaurantId = requireRestaurant(principal);
		List<DiningTable> rows = diningTableRepository.findByRestaurantIdOrderByFloorIndexAscLabelAsc(restaurantId)
				.stream()
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.toList();
		List<WaiterTableRow> out = rows.stream()
				.map(t -> new WaiterTableRow(t.getId(), t.getLabel(), t.getZone(), t.getSeatCount()))
				.toList();
		return new WaiterTablesResponse(out);
	}

	@GetMapping("/menu")
	@PreAuthorize("hasAnyRole('WAITER','RESTAURANT_ADMIN')")
	public GuestMenuPayload menu(@AuthenticationPrincipal QrUserPrincipal principal) {
		return guestMenuService.menuForStaff(requireRestaurant(principal));
	}

	@GetMapping("/ready-lines")
	@PreAuthorize("hasAnyRole('WAITER','RESTAURANT_ADMIN')")
	public KitchenQueuePayload readyLines(@AuthenticationPrincipal QrUserPrincipal principal) {
		UUID restaurantId = requireRestaurant(principal);
		var ready = kitchenQueueService.buildQueue(restaurantId).lines().stream()
				.filter(line -> line.kitchenLineStatus() == KitchenLineStatus.READY)
				.toList();
		return new KitchenQueuePayload(ready);
	}

	@PostMapping("/tables/transfer-orders")
	@PreAuthorize("hasAnyRole('WAITER','RESTAURANT_ADMIN')")
	public TransferTableOrdersResponse transferTableOrders(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@Valid @RequestBody TransferTableOrdersRequest body) {
		UUID restaurantId = requireRestaurant(principal);
		return tableOrderTransferService.transferOpenOrders(restaurantId, body);
	}

	@PostMapping("/orders/{orderId}/lines/{lineId}/delivered")
	@ResponseStatus(HttpStatus.ACCEPTED)
	@PreAuthorize("hasAnyRole('WAITER','RESTAURANT_ADMIN')")
	public void markLineDelivered(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@PathVariable UUID orderId,
			@PathVariable UUID lineId) {
		kitchenLineService.markLineDelivered(requireRestaurant(principal), orderId, lineId);
	}

	@PostMapping("/orders")
	@PreAuthorize("hasAnyRole('WAITER','RESTAURANT_ADMIN')")
	public CreateQrOrderResponse placeOrder(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@Valid @RequestBody WaiterPlaceOrderRequest body) {
		UUID restaurantId = requireRestaurant(principal);
		CreateQrOrderRequest req = new CreateQrOrderRequest(
				restaurantId,
				body.tableId(),
				null,
				body.lines(),
				"WAITER");
		return qrOrderService.placeOrder(req);
	}

	private static UUID requireRestaurant(QrUserPrincipal p) {
		if (p == null || p.restaurantId() == null) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Staff token requires restaurantId");
		}
		return p.restaurantId();
	}

	public record WaiterTablesResponse(List<WaiterTableRow> tables) {
	}

	public record WaiterTableRow(UUID id, String label, String zone, Integer seatCount) {
	}
}
