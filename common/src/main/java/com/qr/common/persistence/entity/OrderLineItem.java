package com.qr.common.persistence.entity;

import java.math.BigDecimal;
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
@Table(name = "order_line_items")
public class OrderLineItem extends BaseEntity {

	@Column(name = "order_id", nullable = false, columnDefinition = "uuid")
	private UUID orderId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "order_id", insertable = false, updatable = false)
	private RestaurantOrder order;

	@Column(name = "product_id", nullable = false, columnDefinition = "uuid")
	private UUID productId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "product_id", insertable = false, updatable = false)
	private Product product;

	@Column(nullable = false)
	private Integer quantity;

	@Column(name = "unit_price", nullable = false, precision = 12, scale = 2)
	private BigDecimal unitPrice;

	@Column(name = "line_total", nullable = false, precision = 12, scale = 2)
	private BigDecimal lineTotal;

	@Column(name = "selected_options", nullable = false, columnDefinition = "json")
	private String selectedOptions = "{}";

	@Column(name = "kitchen_line_status", nullable = false, length = 16)
	@Enumerated(EnumType.STRING)
	private KitchenLineStatus kitchenLineStatus = KitchenLineStatus.PENDING;

	@Column(name = "settled_amount", nullable = false, precision = 12, scale = 2)
	private BigDecimal settledAmount = BigDecimal.ZERO;

	public UUID getOrderId() {
		return orderId;
	}

	public void setOrderId(UUID orderId) {
		this.orderId = orderId;
	}

	@JsonIgnore
	public RestaurantOrder getOrder() {
		return order;
	}

	public UUID getProductId() {
		return productId;
	}

	public void setProductId(UUID productId) {
		this.productId = productId;
	}

	@JsonIgnore
	public Product getProduct() {
		return product;
	}

	public Integer getQuantity() {
		return quantity;
	}

	public void setQuantity(Integer quantity) {
		this.quantity = quantity;
	}

	public BigDecimal getUnitPrice() {
		return unitPrice;
	}

	public void setUnitPrice(BigDecimal unitPrice) {
		this.unitPrice = unitPrice;
	}

	public BigDecimal getLineTotal() {
		return lineTotal;
	}

	public void setLineTotal(BigDecimal lineTotal) {
		this.lineTotal = lineTotal;
	}

	public String getSelectedOptions() {
		return selectedOptions;
	}

	public void setSelectedOptions(String selectedOptions) {
		this.selectedOptions = selectedOptions;
	}

	public KitchenLineStatus getKitchenLineStatus() {
		return kitchenLineStatus;
	}

	public void setKitchenLineStatus(KitchenLineStatus kitchenLineStatus) {
		this.kitchenLineStatus = kitchenLineStatus;
	}

	public BigDecimal getSettledAmount() {
		return settledAmount;
	}

	public void setSettledAmount(BigDecimal settledAmount) {
		this.settledAmount = settledAmount;
	}
}
