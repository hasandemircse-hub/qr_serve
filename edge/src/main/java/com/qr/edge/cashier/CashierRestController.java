package com.qr.edge.cashier;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.security.QrUserPrincipal;
import com.qr.edge.billing.TableClosureReportingService;
import com.qr.edge.billing.TableClosureService;
import com.qr.edge.billing.api.CloseTableSessionRequest;
import com.qr.edge.billing.api.CloseTableSessionResponse;
import com.qr.edge.billing.api.ClosureBalanceReportResponse;
import com.qr.edge.cashier.api.CashierOpenOrdersResponse;


@RestController
@RequestMapping("/api/v1/cashier")
public class CashierRestController {

	private final CashierOpenOrdersService cashierOpenOrdersService;

	private final TableClosureService tableClosureService;

	private final TableClosureReportingService tableClosureReportingService;

	public CashierRestController(
			CashierOpenOrdersService cashierOpenOrdersService,
			TableClosureService tableClosureService,
			TableClosureReportingService tableClosureReportingService) {
		this.cashierOpenOrdersService = cashierOpenOrdersService;
		this.tableClosureService = tableClosureService;
		this.tableClosureReportingService = tableClosureReportingService;
	}

	@GetMapping("/open-orders")
	@PreAuthorize("hasAnyRole('CASHIER','RESTAURANT_ADMIN')")
	public CashierOpenOrdersResponse openOrders(@AuthenticationPrincipal QrUserPrincipal principal) {
		return cashierOpenOrdersService.listOpenWithBalance(requireRestaurant(principal));
	}

	@GetMapping("/balance-report")
	@PreAuthorize("hasAnyRole('CASHIER','RESTAURANT_ADMIN')")
	public ClosureBalanceReportResponse balanceReport(@AuthenticationPrincipal QrUserPrincipal principal) {
		return tableClosureReportingService.buildReport(requireRestaurant(principal));
	}

	@PostMapping("/tables/{tableId}/close-session")
	@PreAuthorize("hasAnyRole('CASHIER','RESTAURANT_ADMIN','WAITER')")
	public CloseTableSessionResponse closeTableSession(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@PathVariable UUID tableId,
			@RequestBody(required = false) CloseTableSessionRequest body) {
		return tableClosureService.closeTableSession(requireRestaurant(principal), tableId, body, principal);
	}

	private static UUID requireRestaurant(QrUserPrincipal p) {
		if (p == null || p.restaurantId() == null) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Staff token requires restaurantId");
		}
		return p.restaurantId();
	}
}
