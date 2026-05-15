package com.qr.common.persistence.entity;

import java.time.LocalDateTime;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Index;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
		name = "sync_metadata",
		uniqueConstraints = @UniqueConstraint(
				name = "uk_sync_metadata_entity_edge",
				columnNames = { "entity_type", "entity_id", "edge_id" }),
		indexes = {
				@Index(name = "idx_sync_metadata_edge_id", columnList = "edge_id"),
				@Index(name = "idx_sync_metadata_entity", columnList = "entity_type, entity_id")
		})
public class SyncMetadata extends BaseEntity {

	@Column(name = "entity_type", nullable = false, length = 64)
	private String entityType;

	@Column(name = "entity_id", nullable = false, columnDefinition = "uuid")
	private UUID entityId;

	@Column(name = "edge_id", nullable = false, columnDefinition = "uuid")
	private UUID edgeId;

	@Column(name = "synced_at", nullable = false)
	private LocalDateTime syncedAt;

	@PrePersist
	private void defaultSyncedAt() {
		if (syncedAt == null) {
			syncedAt = LocalDateTime.now();
		}
	}

	public String getEntityType() {
		return entityType;
	}

	public void setEntityType(String entityType) {
		this.entityType = entityType;
	}

	public UUID getEntityId() {
		return entityId;
	}

	public void setEntityId(UUID entityId) {
		this.entityId = entityId;
	}

	public UUID getEdgeId() {
		return edgeId;
	}

	public void setEdgeId(UUID edgeId) {
		this.edgeId = edgeId;
	}

	public LocalDateTime getSyncedAt() {
		return syncedAt;
	}

	public void setSyncedAt(LocalDateTime syncedAt) {
		this.syncedAt = syncedAt;
	}
}
