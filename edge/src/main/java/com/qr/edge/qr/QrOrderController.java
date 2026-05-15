package com.qr.edge.qr;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.qr.api.CreateQrOrderRequest;
import com.qr.edge.qr.api.CreateQrOrderResponse;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/qr")
@CrossOrigin(originPatterns = { "http://localhost:*", "http://127.0.0.1:*" })
public class QrOrderController {

	private final QrOrderService qrOrderService;

	public QrOrderController(QrOrderService qrOrderService) {
		this.qrOrderService = qrOrderService;
	}

	@PostMapping("/orders")
	public CreateQrOrderResponse createOrder(@Valid @RequestBody CreateQrOrderRequest body) {
		return qrOrderService.placeOrder(body);
	}
}
