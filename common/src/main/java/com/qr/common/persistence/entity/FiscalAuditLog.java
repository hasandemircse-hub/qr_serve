package com.qr.common.persistence.entity;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

@Entity
@Table(name = "fiscal_audit_logs")
public class FiscalAuditLog extends BaseEntity {

	@Column(name = "restaurant_id", nullable = false, columnDefinition = "uuid")
	private UUID restaurantId;

	@Column(name = "order_id", nullable = false, columnDefinition = "uuid")
	private UUID orderId;

	@Column(name = "payment_id", columnDefinition = "uuid")
	private UUID paymentId;

	@Column(name = "event_type", nullable = false, length = 32)
	private String eventType;

	@Column(name = "provider_code", nullable = false, length = 64)
	private String providerCode;

	@Column(name = "correlation_id", nullable = false, length = 64)
	private String correlationId;

	@Column(name = "request_payload", nullable = false, columnDefinition = "TEXT")
	private String requestPayload;

	@Column(name = "response_payload", columnDefinition = "TEXT")
	private String responsePayload;

	@Column(nullable = false, length = 16)
	@Enumerated(EnumType.STRING)
	private FiscalAuditStatus status;

	@Column(name = "error_message", length = 2000)
	private String errorMessage;

	public UUID getRestaurantId() {
		return restaurantId;
	}

	public void setRestaurantId(UUID restaurantId) {
		this.restaurantId = restaurantId;
	}

	public UUID getOrderId() {
		return orderId;
	}

	public void setOrderId(UUID orderId) {
		this.orderId = orderId;
	}

	public UUID getPaymentId() {
		return paymentId;
	}

	public void setPaymentId(UUID paymentId) {
		this.paymentId = paymentId;
	}

	public String getEventType() {
		return eventType;
	}

	public void setEventType(String eventType) {
		this.eventType = eventType;
	}

	public String getProviderCode() {
		return providerCode;
	}

	public void setProviderCode(String providerCode) {
		this.providerCode = providerCode;
	}

	public String getCorrelationId() {
		return correlationId;
	}

	public void setCorrelationId(String correlationId) {
		this.correlationId = correlationId;
	}

	public String getRequestPayload() {
		return requestPayload;
	}

	public void setRequestPayload(String requestPayload) {
		this.requestPayload = requestPayload;
	}

	public String getResponsePayload() {
		return responsePayload;
	}

	public void setResponsePayload(String responsePayload) {
		this.responsePayload = responsePayload;
	}

	public FiscalAuditStatus getStatus() {
		return status;
	}

	public void setStatus(FiscalAuditStatus status) {
		this.status = status;
	}

	public String getErrorMessage() {
		return errorMessage;
	}

	public void setErrorMessage(String errorMessage) {
		this.errorMessage = errorMessage;
	}
}
