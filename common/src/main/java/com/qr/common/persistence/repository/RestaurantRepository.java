package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.Restaurant;

public interface RestaurantRepository extends JpaRepository<Restaurant, UUID> {

	List<Restaurant> findByUpdatedAtAfter(LocalDateTime watermark);
}
