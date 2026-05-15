package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.DiningTable;

public interface DiningTableRepository extends JpaRepository<DiningTable, UUID> {

	List<DiningTable> findByUpdatedAtAfter(LocalDateTime watermark);

	List<DiningTable> findByRestaurantIdOrderByFloorIndexAscLabelAsc(UUID restaurantId);

	boolean existsByIdAndRestaurantId(UUID id, UUID restaurantId);

	List<DiningTable> findByRestaurantIdAndMergeGroupId(UUID restaurantId, UUID mergeGroupId);
}
