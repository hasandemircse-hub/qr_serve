package com.qr.common.persistence.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.qr.common.persistence.entity.FiscalAuditLog;

public interface FiscalAuditLogRepository extends JpaRepository<FiscalAuditLog, UUID> {
}
