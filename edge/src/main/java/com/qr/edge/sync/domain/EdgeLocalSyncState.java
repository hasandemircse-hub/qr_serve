package com.qr.edge.sync.domain;

import java.time.LocalDateTime;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "edge_local_sync_state")
public class EdgeLocalSyncState {

	public static final String SINGLETON_KEY = "DEFAULT";

	@Id
	@Column(name = "singleton_key", length = 16)
	private String singletonKey = SINGLETON_KEY;

	@Column(name = "edge_id", nullable = false, columnDefinition = "uuid")
	private UUID edgeId;

	@Column(name = "cloud_watermark_at", nullable = false)
	private LocalDateTime cloudWatermarkAt;

	@Column(name = "setup_wizard_completed", nullable = false)
	private Boolean setupWizardCompleted = true;

	@Column(name = "setup_wizard_step", length = 64)
	private String setupWizardStep;

	protected EdgeLocalSyncState() {
	}

	public String getSingletonKey() {
		return singletonKey;
	}

	public UUID getEdgeId() {
		return edgeId;
	}

	public void setEdgeId(UUID edgeId) {
		this.edgeId = edgeId;
	}

	public LocalDateTime getCloudWatermarkAt() {
		return cloudWatermarkAt;
	}

	public void setCloudWatermarkAt(LocalDateTime cloudWatermarkAt) {
		this.cloudWatermarkAt = cloudWatermarkAt;
	}

	public Boolean getSetupWizardCompleted() {
		return setupWizardCompleted;
	}

	public void setSetupWizardCompleted(Boolean setupWizardCompleted) {
		this.setupWizardCompleted = setupWizardCompleted;
	}

	public String getSetupWizardStep() {
		return setupWizardStep;
	}

	public void setSetupWizardStep(String setupWizardStep) {
		this.setupWizardStep = setupWizardStep;
	}
}
