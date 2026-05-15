package com.qr.common.persistence.entity;

import java.math.BigDecimal;
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
@Table(name = "payments")
public class Payment extends BaseEntity {

	@Column(name = "order_id", nullable = false, columnDefinition = "uuid")
	private UUID orderId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "order_id", insertable = false, updatable = false)
	private RestaurantOrder order;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Column(nullable = false, length = 32)
	@Enumerated(EnumType.STRING)
	private PaymentMethod method;

	@Column(name = "paid_at", nullable = false)
	private LocalDateTime paidAt;

	@Column(name = "external_reference", length = 255)
	private String externalReference;

	@Column(name = "tip_amount", nullable = false, precision = 12, scale = 2)
	private BigDecimal tipAmount = BigDecimal.ZERO;

	@Column(name = "allocation_kind", nullable = false, length = 32)
	@Enumerated(EnumType.STRING)
	private PaymentAllocationKind allocationKind = PaymentAllocationKind.FIXED_AMOUNT;

	@Column(name = "allocation_details", columnDefinition = "TEXT")
	private String allocationDetailsJson;

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

	public BigDecimal getAmount() {
		return amount;
	}

	public void setAmount(BigDecimal amount) {
		this.amount = amount;
	}

	public PaymentMethod getMethod() {
		return method;
	}

	public void setMethod(PaymentMethod method) {
		this.method = method;
	}

	public LocalDateTime getPaidAt() {
		return paidAt;
	}

	public void setPaidAt(LocalDateTime paidAt) {
		this.paidAt = paidAt;
	}

	public String getExternalReference() {
		return externalReference;
	}

	public void setExternalReference(String externalReference) {
		this.externalReference = externalReference;
	}

	public BigDecimal getTipAmount() {
		return tipAmount;
	}

	public void setTipAmount(BigDecimal tipAmount) {
		this.tipAmount = tipAmount;
	}

	public PaymentAllocationKind getAllocationKind() {
		return allocationKind;
	}

	public void setAllocationKind(PaymentAllocationKind allocationKind) {
		this.allocationKind = allocationKind;
	}

	public String getAllocationDetailsJson() {
		return allocationDetailsJson;
	}

	public void setAllocationDetailsJson(String allocationDetailsJson) {
		this.allocationDetailsJson = allocationDetailsJson;
	}
}
