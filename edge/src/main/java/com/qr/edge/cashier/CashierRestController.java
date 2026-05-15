package com.qr.edge.cashier;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.security.QrUserPrincipal;
import com.qr.edge.cashier.api.CashierOpenOrdersResponse;


@RestController
@RequestMapping("/api/v1/cashier")
public class CashierRestController {

	private final CashierOpenOrdersService cashierOpenOrdersService;

	public CashierRestController(CashierOpenOrdersService cashierOpenOrdersService) {
		this.cashierOpenOrdersService = cashierOpenOrdersService;
	}

	@GetMapping("/open-orders")
	@PreAuthorize("hasAnyRole('CASHIER','RESTAURANT_ADMIN')")
	public CashierOpenOrdersResponse openOrders(@AuthenticationPrincipal QrUserPrincipal principal) {
		return cashierOpenOrdersService.listOpenWithBalance(requireRestaurant(principal));
	}

	private static UUID requireRestaurant(QrUserPrincipal p) {
		if (p == null || p.restaurantId() == null) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Staff token requires restaurantId");
		}
		return p.restaurantId();
	}
}
