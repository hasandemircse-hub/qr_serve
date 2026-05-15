package com.qr.edge.print.billing;

import java.io.IOException;
import java.nio.charset.Charset;

import com.qr.edge.print.PrintManager;
import com.qr.edge.print.config.PrintProperties;
import com.qr.edge.print.escpos.EscPosBuilder;
import com.qr.edge.print.ThermalEscPosPrintService;

/**
 * Adisyon / ödeme fişi: CP1254 / UTF-8 charset {@link PrintProperties} üzerinden; kesim GS V 65 0.
 */
public final class DefaultThermalEscPosPrintService implements ThermalEscPosPrintService {

	private final PrintProperties printProperties;

	private final PrintManager printManager;

	public DefaultThermalEscPosPrintService(PrintProperties printProperties, PrintManager printManager) {
		this.printProperties = printProperties;
		this.printManager = printManager;
	}

	@Override
	public byte[] buildAdisyon(AdisyonSlipModel model) throws IOException {
		Charset charset = Charset.forName(printProperties.getCharset());
		int w = printProperties.getSlipWidthChars();
		EscPosBuilder b = new EscPosBuilder(charset).init();
		b.alignCenter().boldOn().text("ADISYON / ODEME").boldOff().alignLeft();
		b.feed(1);
		b.text(model.restaurantName());
		b.separatorLine(w);
		b.text("Siparis: " + model.orderNumber());
		if (model.tableLabel() != null && !model.tableLabel().isBlank()) {
			b.text("Masa: " + model.tableLabel());
		}
		b.text("Odeme: " + model.paymentMethod());
		b.separatorLine(w);
		for (AdisyonSlipModel.LineEntry line : model.lines()) {
			String head = line.quantity() + " x " + truncate(line.title(), Math.max(4, w - 18));
			b.text(head);
			b.text("  Satir: " + line.lineTotal() + "  Bu odeme: " + line.settledByThisPayment());
		}
		b.separatorLine(w);
		b.text("Siparis toplami: " + model.orderTotal());
		b.text("Ana tutar (bu fis): " + model.principalThisPayment());
		b.text("Bahsis: " + model.tipAmount());
		b.boldOn().text("Kalan bakiye: " + model.remainingAfterPayment()).boldOff();
		if (model.footerNote() != null && !model.footerNote().isBlank()) {
			b.feed(1);
			b.alignCenter().text(model.footerNote()).alignLeft();
		}
		b.feed(2);
		b.partialCut();
		return b.toBytes();
	}

	private static String truncate(String s, int max) {
		if (s == null) {
			return "";
		}
		return s.length() <= max ? s : s.substring(0, max - 1) + "…";
	}

	@Override
	public void sendToPrinter(String printerId, byte[] escPosPayload) {
		printManager.enqueue(printerId, escPosPayload);
	}
}
