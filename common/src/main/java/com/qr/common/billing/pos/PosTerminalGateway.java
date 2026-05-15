package com.qr.common.billing.pos;

/**
 * Fiziksel POS veya banka terminaline ödeme bilgisini ileten katman (HTTP, seri port vb. uygulamada bağlanır).
 */
public interface PosTerminalGateway {

	PosOperationResult notifyPayment(PosPaymentIntent intent);
}
