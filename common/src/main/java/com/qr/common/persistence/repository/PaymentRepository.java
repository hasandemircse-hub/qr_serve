package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.Payment;

public interface PaymentRepository extends JpaRepository<Payment, UUID> {

	List<Payment> findByUpdatedAtAfter(LocalDateTime watermark);

	List<Payment> findByOrderIdAndIsDeletedFalseOrderByPaidAtAsc(UUID orderId);

	List<Payment> findByOrderIdOrderByPaidAtAsc(UUID orderId);
}
