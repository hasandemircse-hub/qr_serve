package com.qr.common.persistence.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.ProductOptionGroup;

public interface ProductOptionGroupRepository extends JpaRepository<ProductOptionGroup, UUID> {

	List<ProductOptionGroup> findByUpdatedAtAfter(java.time.LocalDateTime watermark);

	List<ProductOptionGroup> findByProductIdOrderBySortIndexAsc(UUID productId);

	List<ProductOptionGroup> findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(UUID productId);
}
