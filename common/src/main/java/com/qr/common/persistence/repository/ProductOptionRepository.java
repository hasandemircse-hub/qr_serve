package com.qr.common.persistence.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.ProductOption;

public interface ProductOptionRepository extends JpaRepository<ProductOption, UUID> {

	List<ProductOption> findByUpdatedAtAfter(java.time.LocalDateTime watermark);

	List<ProductOption> findByOptionGroupIdOrderBySortIndexAsc(UUID optionGroupId);

	List<ProductOption> findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(UUID optionGroupId);
}
