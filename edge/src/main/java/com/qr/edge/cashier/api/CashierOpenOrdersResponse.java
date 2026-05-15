package com.qr.edge.cashier.api;

import java.util.List;

public record CashierOpenOrdersResponse(List<CashierOpenOrderRow> orders) {
}
