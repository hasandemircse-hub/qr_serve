package com.qr.common.persistence.entity;

import java.time.LocalDateTime;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnore;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "customer_orders")
public class RestaurantOrder extends BaseEntity {

	@Column(name = "restaurant_id", nullable = false, columnDefinition = "uuid")
	private UUID restaurantId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "restaurant_id", insertable = false, updatable = false)
	private Restaurant restaurant;

	@Column(name = "table_id", columnDefinition = "uuid")
	private UUID tableId;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "table_id", insertable = false, updatable = false)
	private DiningTable diningTable;

	@Column(nullable = false, length = 32)
	@Enumerated(EnumType.STRING)
	private OrderStatus status;

	@Column(name = "order_number", length = 64)
	private String orderNumber;

	@Column(name = "ordered_at", nullable = false)
	private LocalDateTime orderedAt;

	@Column(length = 2000)
	private String notes;

	@Column(name = "guest_token", length = 128)
	private String guestToken;

	public UUID getRestaurantId() {
		return restaurantId;
	}

	public void setRestaurantId(UUID restaurantId) {
		this.restaurantId = restaurantId;
	}

	@JsonIgnore
	public Restaurant getRestaurant() {
		return restaurant;
	}

	public UUID getTableId() {
		return tableId;
	}

	public void setTableId(UUID tableId) {
		this.tableId = tableId;
	}

	@JsonIgnore
	public DiningTable getDiningTable() {
		return diningTable;
	}

	public OrderStatus getStatus() {
		return status;
	}

	public void setStatus(OrderStatus status) {
		this.status = status;
	}

	public String getOrderNumber() {
		return orderNumber;
	}

	public void setOrderNumber(String orderNumber) {
		this.orderNumber = orderNumber;
	}

	public LocalDateTime getOrderedAt() {
		return orderedAt;
	}

	public void setOrderedAt(LocalDateTime orderedAt) {
		this.orderedAt = orderedAt;
	}

	public String getNotes() {
		return notes;
	}

	public void setNotes(String notes) {
		this.notes = notes;
	}

	public String getGuestToken() {
		return guestToken;
	}

	public void setGuestToken(String guestToken) {
		this.guestToken = guestToken;
	}
}
