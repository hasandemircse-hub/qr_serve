package com.qr.edge.billing;

import java.util.UUID;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.billing.api.BillingPaymentResponse;
import com.qr.edge.billing.api.BillingRefundResponse;
import com.qr.edge.billing.api.BillingSummaryResponse;
import com.qr.edge.billing.api.ProcessPaymentRequest;
import com.qr.edge.billing.api.RefundPaymentRequest;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}/orders/{orderId}/billing")
public class BillingController {

	private final BillingPaymentService billingPaymentService;

	private final BillingRefundService billingRefundService;

	public BillingController(
			BillingPaymentService billingPaymentService,
			BillingRefundService billingRefundService) {
		this.billingPaymentService = billingPaymentService;
		this.billingRefundService = billingRefundService;
	}

	@GetMapping
	@PreAuthorize("@edgeAuth.canProcessPayments(authentication, #restaurantId)")
	public BillingSummaryResponse getSummary(
			@PathVariable UUID restaurantId,
			@PathVariable UUID orderId) {
		return billingPaymentService.getSummary(restaurantId, orderId);
	}

	@PostMapping("/payments")
	@PreAuthorize("@edgeAuth.canProcessPayments(authentication, #restaurantId)")
	public BillingPaymentResponse pay(
			@PathVariable UUID restaurantId,
			@PathVariable UUID orderId,
			@Valid @RequestBody ProcessPaymentRequest body) {
		return billingPaymentService.pay(restaurantId, orderId, body);
	}

	@PostMapping("/payments/{paymentId}/refund")
	@ResponseStatus(HttpStatus.OK)
	@PreAuthorize("@edgeAuth.canProcessPayments(authentication, #restaurantId)")
	public BillingRefundResponse refund(
			@PathVariable UUID restaurantId,
			@PathVariable UUID orderId,
			@PathVariable UUID paymentId,
			@RequestBody(required = false) @Valid RefundPaymentRequest body) {
		return billingRefundService.refund(restaurantId, orderId, paymentId, body);
	}
}
