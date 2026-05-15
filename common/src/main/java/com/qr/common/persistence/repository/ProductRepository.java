package com.qr.common.persistence.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.Product;

public interface ProductRepository extends JpaRepository<Product, UUID> {

	List<Product> findByUpdatedAtAfter(LocalDateTime watermark);

	List<Product> findByMenuIdAndIsDeletedFalseOrderByNameAsc(UUID menuId);
}
