package com.qr.common.persistence.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.EdgeSyncCheckpoint;

public interface EdgeSyncCheckpointRepository extends JpaRepository<EdgeSyncCheckpoint, UUID> {

	Optional<EdgeSyncCheckpoint> findFirstByRegisteredRestaurantIdOrderByLastHelloAtDesc(UUID registeredRestaurantId);

	List<EdgeSyncCheckpoint> findByRegisteredRestaurantId(UUID registeredRestaurantId);
}
