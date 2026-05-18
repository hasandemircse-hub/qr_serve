package com.qr.common.persistence.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

@Entity
@Table(name = "table_closure_audit_logs")
public class TableClosureAuditLog extends BaseEntity {

	@Column(name = "restaurant_id", nullable = false, columnDefinition = "uuid")
	private UUID restaurantId;

	@Column(name = "table_id", nullable = false, columnDefinition = "uuid")
	private UUID tableId;

	@Column(name = "order_id", nullable = false, columnDefinition = "uuid")
	private UUID orderId;

	@Column(nullable = false, length = 32)
	@Enumerated(EnumType.STRING)
	private TableClosurePolicy policy;

	@Column(name = "reason_code", nullable = false, length = 48)
	@Enumerated(EnumType.STRING)
	private TableClosureReasonCode reasonCode;

	@Column(name = "actor_user_id", columnDefinition = "uuid")
	private UUID actorUserId;

	@Column(name = "actor_role", length = 48)
	private String actorRole;

	@Column(name = "remaining_principal", nullable = false, precision = 12, scale = 2)
	private BigDecimal remainingPrincipal;

	@Column(name = "closed_at", nullable = false)
	private LocalDateTime closedAt;

	@Column(length = 1000)
	private String note;

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

	public UUID getOrderId() {
		return orderId;
	}

	public void setOrderId(UUID orderId) {
		this.orderId = orderId;
	}

	public TableClosurePolicy getPolicy() {
		return policy;
	}

	public void setPolicy(TableClosurePolicy policy) {
		this.policy = policy;
	}

	public TableClosureReasonCode getReasonCode() {
		return reasonCode;
	}

	public void setReasonCode(TableClosureReasonCode reasonCode) {
		this.reasonCode = reasonCode;
	}

	public UUID getActorUserId() {
		return actorUserId;
	}

	public void setActorUserId(UUID actorUserId) {
		this.actorUserId = actorUserId;
	}

	public String getActorRole() {
		return actorRole;
	}

	public void setActorRole(String actorRole) {
		this.actorRole = actorRole;
	}

	public BigDecimal getRemainingPrincipal() {
		return remainingPrincipal;
	}

	public void setRemainingPrincipal(BigDecimal remainingPrincipal) {
		this.remainingPrincipal = remainingPrincipal;
	}

	public LocalDateTime getClosedAt() {
		return closedAt;
	}

	public void setClosedAt(LocalDateTime closedAt) {
		this.closedAt = closedAt;
	}

	public String getNote() {
		return note;
	}

	public void setNote(String note) {
		this.note = note;
	}
}
