package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;

public interface RestaurantOrderRepository extends JpaRepository<RestaurantOrder, UUID> {

	List<RestaurantOrder> findByUpdatedAtAfter(LocalDateTime watermark);

	Optional<RestaurantOrder> findByIdAndRestaurantId(UUID id, UUID restaurantId);

	List<RestaurantOrder> findByRestaurantIdOrderByUpdatedAtAsc(UUID restaurantId);

	List<RestaurantOrder> findByRestaurantIdAndStatusOrderByOrderedAtDesc(UUID restaurantId, OrderStatus status);

	List<RestaurantOrder> findByRestaurantIdAndIsDeletedFalseAndStatusNotInOrderByOrderedAtDesc(
			UUID restaurantId,
			Collection<OrderStatus> statuses);

	List<RestaurantOrder> findByRestaurantIdAndTableIdAndGuestTokenAndIsDeletedFalseAndStatusNotInOrderByOrderedAtDesc(
			UUID restaurantId,
			UUID tableId,
			String guestToken,
			Collection<OrderStatus> statuses);
}
