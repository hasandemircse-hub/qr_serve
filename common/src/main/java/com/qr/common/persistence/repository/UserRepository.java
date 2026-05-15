package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.User;

public interface UserRepository extends JpaRepository<User, UUID> {

	Optional<User> findByEmailIgnoreCase(String email);

	List<User> findByUpdatedAtAfter(LocalDateTime watermark);

	List<User> findByRestaurantId(UUID restaurantId);
}
