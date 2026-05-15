package com.qr.common.billing.fiscal;

import java.util.Optional;

/**
 * Türkiye GİB E-Fatura / E-Adisyon sağlayıcıları için genişletilebilir köprü.
 * Yasal iz için her çağrı uygulama tarafında kalıcı denetim günlüğüne yazılmalıdır.
 */
public interface InvoicingProvider {

	String providerCode();

	boolean supports(FiscalDocumentKind kind);

	/**
	 * Belgeyi GİB / aracı entegrasyona iletir; ağ hatalarında exception fırlatır.
	 */
	FiscalSubmitResult submit(FiscalSalesDocumentRequest request);

	Optional<FiscalSubmitResult> queryByCorrelation(String correlationId);
}
