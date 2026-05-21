package com.qr.common.persistence.entity;

import java.time.LocalDateTime;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "edge_sync_checkpoint")
public class EdgeSyncCheckpoint {

	@Id
	@Column(name = "edge_id", columnDefinition = "uuid")
	private UUID edgeId;

	@Column(name = "last_acknowledged_updated_at", nullable = false)
	private LocalDateTime lastAcknowledgedUpdatedAt;

	@Column(name = "public_edge_url", length = 512)
	private String publicEdgeUrl;

	@Column(name = "last_hello_at")
	private LocalDateTime lastHelloAt;

	@Column(name = "registered_restaurant_id", columnDefinition = "uuid")
	private UUID registeredRestaurantId;

	@Column(name = "software_version", length = 64)
	private String softwareVersion;

	protected EdgeSyncCheckpoint() {
	}

	public EdgeSyncCheckpoint(UUID edgeId, LocalDateTime lastAcknowledgedUpdatedAt) {
		this.edgeId = edgeId;
		this.lastAcknowledgedUpdatedAt = lastAcknowledgedUpdatedAt;
	}

	public UUID getEdgeId() {
		return edgeId;
	}

	public LocalDateTime getLastAcknowledgedUpdatedAt() {
		return lastAcknowledgedUpdatedAt;
	}

	public void setLastAcknowledgedUpdatedAt(LocalDateTime lastAcknowledgedUpdatedAt) {
		this.lastAcknowledgedUpdatedAt = lastAcknowledgedUpdatedAt;
	}

	public String getPublicEdgeUrl() {
		return publicEdgeUrl;
	}

	public void setPublicEdgeUrl(String publicEdgeUrl) {
		this.publicEdgeUrl = publicEdgeUrl;
	}

	public LocalDateTime getLastHelloAt() {
		return lastHelloAt;
	}

	public void setLastHelloAt(LocalDateTime lastHelloAt) {
		this.lastHelloAt = lastHelloAt;
	}

	public UUID getRegisteredRestaurantId() {
		return registeredRestaurantId;
	}

	public void setRegisteredRestaurantId(UUID registeredRestaurantId) {
		this.registeredRestaurantId = registeredRestaurantId;
	}

	public String getSoftwareVersion() {
		return softwareVersion;
	}

	public void setSoftwareVersion(String softwareVersion) {
		this.softwareVersion = softwareVersion;
	}
}
