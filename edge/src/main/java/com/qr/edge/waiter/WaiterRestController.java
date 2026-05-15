package com.qr.edge.waiter;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.security.QrUserPrincipal;
import com.qr.edge.guest.GuestMenuService;
import com.qr.edge.guest.api.GuestMenuPayload;
import com.qr.edge.qr.QrOrderService;
import com.qr.edge.qr.api.CreateQrOrderRequest;
import com.qr.edge.qr.api.CreateQrOrderResponse;
import com.qr.edge.waiter.api.WaiterPlaceOrderRequest;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/waiter")
public class WaiterRestController {

	private final DiningTableRepository diningTableRepository;

	private final GuestMenuService guestMenuService;

	private final QrOrderService qrOrderService;

	public WaiterRestController(
			DiningTableRepository diningTableRepository,
			GuestMenuService guestMenuService,
			QrOrderService qrOrderService) {
		this.diningTableRepository = diningTableRepository;
		this.guestMenuService = guestMenuService;
		this.qrOrderService = qrOrderService;
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
