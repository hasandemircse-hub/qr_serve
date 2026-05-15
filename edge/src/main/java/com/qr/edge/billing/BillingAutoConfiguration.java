package com.qr.edge.billing;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.billing.fiscal.InvoicingProvider;
import com.qr.common.billing.pos.PosTerminalGateway;
import com.qr.edge.billing.fiscal.NoOpInvoicingProvider;
import com.qr.edge.billing.pos.LoggingPosTerminalGateway;
import com.qr.edge.print.PrintManager;
import com.qr.edge.print.ThermalEscPosPrintService;
import com.qr.edge.print.billing.DefaultThermalEscPosPrintService;
import com.qr.edge.print.config.PrintProperties;


@Configuration
public class BillingAutoConfiguration {

	@Bean
	@Primary
	InvoicingProvider invoicingProvider() {
		return new NoOpInvoicingProvider();
	}

	@Bean
	@Primary
	PosTerminalGateway posTerminalGateway(ObjectMapper objectMapper) {
		return new LoggingPosTerminalGateway(objectMapper);
	}

	@Bean
	ThermalEscPosPrintService thermalEscPosPrintService(PrintProperties printProperties, PrintManager printManager) {
		return new DefaultThermalEscPosPrintService(printProperties, printManager);
	}
}
