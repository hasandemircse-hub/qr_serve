package com.qr.edge.print;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.print.config.PrintProperties;
import com.qr.edge.print.escpos.EscPosBuilder;

import java.nio.charset.Charset;

@RestController
@RequestMapping("/api/v1/print")
public class PrintTestController {

	private final PrintManager printManager;

	private final PrintProperties printProperties;

	public PrintTestController(PrintManager printManager, PrintProperties printProperties) {
		this.printManager = printManager;
		this.printProperties = printProperties;
	}

	@PostMapping("/printers/{printerId}/test")
	@ResponseStatus(HttpStatus.ACCEPTED)
	@PreAuthorize("hasAnyRole('CASHIER','RESTAURANT_ADMIN','KITCHEN','SUPERADMIN')")
	public void testPrint(@PathVariable String printerId) throws Exception {
		Charset charset = Charset.forName(printProperties.getCharset());
		byte[] demo = new EscPosBuilder(charset).init()
				.text("QuickServe test")
				.text("Yazici: " + printerId)
				.feed(2)
				.partialCut()
				.toBytes();
		printManager.enqueue(printerId, demo);
	}
}
