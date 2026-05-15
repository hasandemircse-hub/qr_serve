package com.qr.common.security;

/**
 * Uygulama rolleri (Spring Security ile ROLE_ öneki kullanılır).
 */
public enum UserRole {
	SUPERADMIN,
	RESTAURANT_ADMIN,
	WAITER,
	KITCHEN,
	CASHIER
}
