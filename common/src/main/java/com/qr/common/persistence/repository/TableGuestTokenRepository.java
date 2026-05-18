package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.TableGuestToken;

public interface TableGuestTokenRepository extends JpaRepository<TableGuestToken, UUID> {

	Optional<TableGuestToken> findByRestaurantIdAndTableIdAndTokenAndIsDeletedFalseAndExpiresAtAfter(
			UUID restaurantId,
			UUID tableId,
			String token,
			LocalDateTime now);

	Optional<TableGuestToken> findFirstByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(
			UUID restaurantId,
			UUID tableId);

	List<TableGuestToken> findByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(
			UUID restaurantId,
			UUID tableId);
}
