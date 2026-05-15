package com.qr.edge.billing.fiscal;

import java.util.Optional;

import com.qr.common.billing.fiscal.FiscalDocumentKind;
import com.qr.common.billing.fiscal.FiscalSalesDocumentRequest;
import com.qr.common.billing.fiscal.FiscalSubmitResult;
import com.qr.common.billing.fiscal.InvoicingProvider;

/**
 * GİB entegrasyonu yokken: üretimde gerçek sağlayıcı bean'i ile değiştirin.
 */
public final class NoOpInvoicingProvider implements InvoicingProvider {

	@Override
	public String providerCode() {
		return "NOOP";
	}

	@Override
	public boolean supports(FiscalDocumentKind kind) {
		return true;
	}

	@Override
	public FiscalSubmitResult submit(FiscalSalesDocumentRequest request) {
		return FiscalSubmitResult.ok("NOOP-" + request.paymentId(), "{\"stub\":true}");
	}

	@Override
	public Optional<FiscalSubmitResult> queryByCorrelation(String correlationId) {
		return Optional.empty();
	}
}
