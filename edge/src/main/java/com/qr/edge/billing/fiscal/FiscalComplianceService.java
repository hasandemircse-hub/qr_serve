package com.qr.edge.billing.fiscal;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.billing.fiscal.FiscalDocumentKind;
import com.qr.common.billing.fiscal.FiscalSalesDocumentRequest;
import com.qr.common.billing.fiscal.FiscalSalesDocumentRequest.FiscalLineSnapshot;
import com.qr.common.billing.fiscal.FiscalSubmitResult;
import com.qr.common.billing.fiscal.InvoicingProvider;
import com.qr.common.persistence.entity.FiscalAuditLog;
import com.qr.common.persistence.entity.FiscalAuditStatus;
import com.qr.common.persistence.entity.Payment;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.FiscalAuditLogRepository;


@Service
public class FiscalComplianceService {

	private static final Logger log = LoggerFactory.getLogger(FiscalComplianceService.class);

	private final FiscalAuditLogRepository fiscalAuditLogRepository;

	private final InvoicingProvider invoicingProvider;

	private final ObjectMapper objectMapper;

	private final Clock clock;

	public FiscalComplianceService(
			FiscalAuditLogRepository fiscalAuditLogRepository,
			InvoicingProvider invoicingProvider,
			ObjectMapper objectMapper,
			Clock clock) {
		this.fiscalAuditLogRepository = fiscalAuditLogRepository;
		this.invoicingProvider = invoicingProvider;
		this.objectMapper = objectMapper;
		this.clock = clock;
	}

	@Transactional
	public void recordAdisyonAttempt(
			UUID restaurantId,
			RestaurantOrder order,
			Payment payment,
			List<FiscalLineSnapshot> lines,
			String allocationJson) {
		UUID correlation = UUID.randomUUID();
		FiscalSalesDocumentRequest request = new FiscalSalesDocumentRequest(
				restaurantId,
				order.getId(),
				payment.getId(),
				FiscalDocumentKind.E_ADISYON,
				"TRY",
				payment.getAmount(),
				payment.getTipAmount() != null ? payment.getTipAmount() : java.math.BigDecimal.ZERO,
				OffsetDateTime.now(clock),
				lines);
		FiscalAuditLog row = new FiscalAuditLog();
		row.setRestaurantId(restaurantId);
		row.setOrderId(order.getId());
		row.setPaymentId(payment.getId());
		row.setEventType("E_ADISYON_SUBMIT");
		row.setProviderCode(invoicingProvider.providerCode());
		row.setCorrelationId(correlation.toString());
		try {
			row.setRequestPayload(objectMapper.writeValueAsString(request) + " | allocation=" + allocationJson);
		} catch (JsonProcessingException e) {
			row.setRequestPayload("{\"error\":\"serialize\"}");
		}
		row.setStatus(FiscalAuditStatus.PENDING);
		fiscalAuditLogRepository.save(row);
		try {
			FiscalSubmitResult result = invoicingProvider.submit(request);
			row.setStatus(result.success() ? FiscalAuditStatus.SUCCESS : FiscalAuditStatus.FAILED);
			row.setResponsePayload(result.rawResponse());
			if (!result.success()) {
				row.setErrorMessage("Provider declined");
			}
		} catch (RuntimeException ex) {
			log.warn("Fiscal submit failed: {}", ex.getMessage());
			row.setStatus(FiscalAuditStatus.FAILED);
			row.setErrorMessage(truncate(ex.getMessage(), 1900));
		}
		fiscalAuditLogRepository.save(row);
	}

	private static String truncate(String s, int max) {
		if (s == null) {
			return null;
		}
		return s.length() <= max ? s : s.substring(0, max);
	}
}
