package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.TableClosureAuditLog;

public interface TableClosureAuditLogRepository extends JpaRepository<TableClosureAuditLog, UUID> {

	List<TableClosureAuditLog> findByUpdatedAtAfter(LocalDateTime watermark);

	List<TableClosureAuditLog> findByRestaurantIdAndIsDeletedFalseOrderByClosedAtDesc(UUID restaurantId);
}
