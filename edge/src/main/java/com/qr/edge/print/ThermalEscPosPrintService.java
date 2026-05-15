package com.qr.edge.print;

import java.io.IOException;

import com.qr.edge.print.billing.AdisyonSlipModel;

/**
 * ESC/POS uyumlu termal çıktı: marka bağımsız ham bayt üretimi + kuyruk üzerinden gönderim.
 */
public interface ThermalEscPosPrintService {

	byte[] buildAdisyon(AdisyonSlipModel model) throws IOException;

	void sendToPrinter(String printerId, byte[] escPosPayload);
}
