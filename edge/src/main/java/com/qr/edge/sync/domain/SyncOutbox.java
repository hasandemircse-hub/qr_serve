package com.qr.edge.sync.domain;

import java.util.UUID;

import com.qr.common.persistence.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

@Entity
@Table(name = "sync_outbox")
public class SyncOutbox extends BaseEntity {

	@Column(name = "batch_id", nullable = false, columnDefinition = "uuid")
	private UUID batchId;

	@Column(name = "edge_id", nullable = false, columnDefinition = "uuid")
	private UUID edgeId;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private SyncOutboxStatus status = SyncOutboxStatus.PENDING;

	@Column(name = "attempt_count", nullable = false)
	private int attemptCount;

	@Column(name = "next_attempt_at")
	private java.time.LocalDateTime nextAttemptAt;

	@Column(name = "payload_json", nullable = false, columnDefinition = "TEXT")
	private String payloadJson;

	public UUID getBatchId() {
		return batchId;
	}

	public void setBatchId(UUID batchId) {
		this.batchId = batchId;
	}

	public UUID getEdgeId() {
		return edgeId;
	}

	public void setEdgeId(UUID edgeId) {
		this.edgeId = edgeId;
	}

	public SyncOutboxStatus getStatus() {
		return status;
	}

	public void setStatus(SyncOutboxStatus status) {
		this.status = status;
	}

	public int getAttemptCount() {
		return attemptCount;
	}

	public void setAttemptCount(int attemptCount) {
		this.attemptCount = attemptCount;
	}

	public java.time.LocalDateTime getNextAttemptAt() {
		return nextAttemptAt;
	}

	public void setNextAttemptAt(java.time.LocalDateTime nextAttemptAt) {
		this.nextAttemptAt = nextAttemptAt;
	}

	public String getPayloadJson() {
		return payloadJson;
	}

	public void setPayloadJson(String payloadJson) {
		this.payloadJson = payloadJson;
	}
}
