package com.qr.edge.sync.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.edge.sync.domain.SyncOutbox;
import com.qr.edge.sync.domain.SyncOutboxStatus;

public interface SyncOutboxRepository extends JpaRepository<SyncOutbox, UUID> {

	List<SyncOutbox> findTop50ByStatusOrderByCreatedAtAsc(SyncOutboxStatus status);
}
