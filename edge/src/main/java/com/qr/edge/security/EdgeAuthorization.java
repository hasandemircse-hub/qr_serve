package com.qr.edge.security;

import java.util.UUID;

import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

import com.qr.common.security.QrUserPrincipal;
import com.qr.common.security.UserRole;

@Component("edgeAuth")
public class EdgeAuthorization {

	public boolean canAccessRestaurant(Authentication authentication, UUID restaurantId) {
		if (authentication == null || !(authentication.getPrincipal() instanceof QrUserPrincipal p)) {
			return false;
		}
		if (p.role() == UserRole.SUPERADMIN) {
			return true;
		}
		return p.restaurantId() != null && p.restaurantId().equals(restaurantId);
	}

	public boolean isRestaurantAdmin(Authentication authentication, UUID restaurantId) {
		if (authentication == null || !(authentication.getPrincipal() instanceof QrUserPrincipal p)) {
			return false;
		}
		if (p.role() == UserRole.SUPERADMIN) {
			return true;
		}
		return p.role() == UserRole.RESTAURANT_ADMIN && p.restaurantId() != null
				&& p.restaurantId().equals(restaurantId);
	}

	public boolean canViewFloorPlan(Authentication authentication, UUID restaurantId) {
		if (!canAccessRestaurant(authentication, restaurantId)) {
			return false;
		}
		QrUserPrincipal p = (QrUserPrincipal) authentication.getPrincipal();
		return switch (p.role()) {
			case SUPERADMIN, RESTAURANT_ADMIN, WAITER, CASHIER -> true;
			case KITCHEN -> false;
		};
	}

	public boolean canProcessPayments(Authentication authentication, UUID restaurantId) {
		if (!canAccessRestaurant(authentication, restaurantId)) {
			return false;
		}
		QrUserPrincipal p = (QrUserPrincipal) authentication.getPrincipal();
		return switch (p.role()) {
			case SUPERADMIN, RESTAURANT_ADMIN, CASHIER -> true;
			case WAITER, KITCHEN -> false;
		};
	}
}
