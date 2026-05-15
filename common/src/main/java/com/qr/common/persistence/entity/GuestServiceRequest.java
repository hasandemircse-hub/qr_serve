package com.qr.common.persistence.entity;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

@Entity
@Table(name = "guest_service_requests")
public class GuestServiceRequest extends BaseEntity {

	@Column(name = "restaurant_id", nullable = false, columnDefinition = "uuid")
	private UUID restaurantId;

	@Column(name = "table_id", nullable = false, columnDefinition = "uuid")
	private UUID tableId;

	@Column(name = "guest_token", nullable = false, length = 128)
	private String guestToken;

	@Column(name = "request_type", nullable = false, length = 32)
	@Enumerated(EnumType.STRING)
	private GuestServiceRequestType requestType;

	public UUID getRestaurantId() {
		return restaurantId;
	}

	public void setRestaurantId(UUID restaurantId) {
		this.restaurantId = restaurantId;
	}

	public UUID getTableId() {
		return tableId;
	}

	public void setTableId(UUID tableId) {
		this.tableId = tableId;
	}

	public String getGuestToken() {
		return guestToken;
	}

	public void setGuestToken(String guestToken) {
		this.guestToken = guestToken;
	}

	public GuestServiceRequestType getRequestType() {
		return requestType;
	}

	public void setRequestType(GuestServiceRequestType requestType) {
		this.requestType = requestType;
	}
}
