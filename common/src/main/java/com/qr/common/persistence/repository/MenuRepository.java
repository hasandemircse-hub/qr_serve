package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.Menu;

public interface MenuRepository extends JpaRepository<Menu, UUID> {

	List<Menu> findByRestaurantIdAndIsDeletedFalseAndActiveTrueOrderBySortIndexAscNameAsc(UUID restaurantId);

	List<Menu> findByRestaurantIdAndIsDeletedFalseOrderBySortIndexAscNameAsc(UUID restaurantId);

	List<Menu> findByUpdatedAtAfter(LocalDateTime watermark);
}
