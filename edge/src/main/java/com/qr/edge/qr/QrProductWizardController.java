package com.qr.edge.qr;

import java.util.UUID;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.qr.api.ProductOptionWizardResponse;

@RestController
@RequestMapping("/api/v1/qr/products")
@CrossOrigin(originPatterns = { "http://localhost:*", "http://127.0.0.1:*" })
public class QrProductWizardController {

	private final ProductOptionWizardService productOptionWizardService;

	public QrProductWizardController(ProductOptionWizardService productOptionWizardService) {
		this.productOptionWizardService = productOptionWizardService;
	}

	@GetMapping("/{productId}/option-wizard")
	public ProductOptionWizardResponse optionWizard(@PathVariable UUID productId) {
		return productOptionWizardService.buildWizard(productId);
	}
}
