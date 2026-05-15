package com.qr.edge.sync.repo;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.edge.sync.domain.EdgeLocalSyncState;

public interface EdgeLocalSyncStateRepository extends JpaRepository<EdgeLocalSyncState, String> {
}
