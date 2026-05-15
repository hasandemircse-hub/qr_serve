package com.qr.common.persistence.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.OrderLineItem;

public interface OrderLineItemRepository extends JpaRepository<OrderLineItem, UUID> {

	List<OrderLineItem> findByUpdatedAtAfter(java.time.LocalDateTime watermark);

	List<OrderLineItem> findByOrderIdOrderByCreatedAtAsc(UUID orderId);
}
