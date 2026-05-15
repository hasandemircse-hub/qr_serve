package com.qr.common.persistence.entity;

import java.time.LocalDateTime;
import java.util.UUID;

import org.springframework.data.domain.Persistable;

import jakarta.persistence.Column;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Transient;
import jakarta.persistence.Version;

@MappedSuperclass
public abstract class BaseEntity implements Persistable<UUID> {

	@Transient
	private boolean newEntity = true;

	@Id
	@Column(columnDefinition = "uuid", updatable = false, nullable = false)
	private UUID id;

	@Column(name = "created_at", nullable = false, updatable = false)
	private LocalDateTime createdAt;

	@Column(name = "updated_at", nullable = false)
	private LocalDateTime updatedAt;

	@Version
	@Column(nullable = false)
	private Long version = 0L;

	@Column(name = "is_deleted", nullable = false)
	private Boolean isDeleted = false;

	@Override
	public boolean isNew() {
		return newEntity;
	}

	/**
	 * Assigns a UUID (and timestamps if missing) before persist when callers need
	 * {@link #getId()} immediately after {@code save()} (Hibernate may defer {@link PrePersist} until flush).
	 */
	public void assignIdIfAbsent() {
		if (id == null) {
			id = UUID.randomUUID();
		}
		touchTimestampsIfAbsent();
	}

	@PrePersist
	protected void prePersist() {
		assignIdIfAbsent();
	}

	@PreUpdate
	protected void preUpdate() {
		updatedAt = LocalDateTime.now();
	}

	@PostPersist
	@PostLoad
	void markNotNew() {
		newEntity = false;
	}

	private void touchTimestampsIfAbsent() {
		LocalDateTime now = LocalDateTime.now();
		if (createdAt == null) {
			createdAt = now;
		}
		if (updatedAt == null) {
			updatedAt = now;
		}
	}

	@Override
	public UUID getId() {
		return id;
	}

	public void setId(UUID id) {
		this.id = id;
	}

	public LocalDateTime getCreatedAt() {
		return createdAt;
	}

	public void setCreatedAt(LocalDateTime createdAt) {
		this.createdAt = createdAt;
	}

	public LocalDateTime getUpdatedAt() {
		return updatedAt;
	}

	public void setUpdatedAt(LocalDateTime updatedAt) {
		this.updatedAt = updatedAt;
	}

	public Long getVersion() {
		return version;
	}

	public void setVersion(Long version) {
		this.version = version;
	}

	public Boolean getIsDeleted() {
		return isDeleted;
	}

	public void setIsDeleted(Boolean isDeleted) {
		this.isDeleted = isDeleted;
	}
}
