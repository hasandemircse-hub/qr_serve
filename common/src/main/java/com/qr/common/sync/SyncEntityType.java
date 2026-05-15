package com.qr.common.sync;

public enum SyncEntityType {
	RESTAURANT(0),
	USER(1),
	DINING_TABLE(2),
	MENU(3),
	PRODUCT(4),
	PRODUCT_OPTION_GROUP(5),
	PRODUCT_OPTION(6),
	CUSTOMER_ORDER(7),
	ORDER_LINE_ITEM(8),
	PAYMENT(9);

	private final int mergeOrder;

	SyncEntityType(int mergeOrder) {
		this.mergeOrder = mergeOrder;
	}

	public int mergeOrder() {
		return mergeOrder;
	}
}
