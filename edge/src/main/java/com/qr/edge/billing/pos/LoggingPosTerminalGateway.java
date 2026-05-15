package com.qr.edge.billing.pos;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.billing.pos.PosOperationResult;
import com.qr.common.billing.pos.PosPaymentIntent;
import com.qr.common.billing.pos.PosTerminalGateway;

/**
 * JSON tabanlı POS protokolü için yer tutucu: gerçek entegrasyonda HTTP/seri port istemcisi bağlanır.
 */
public final class LoggingPosTerminalGateway implements PosTerminalGateway {

	private static final Logger log = LoggerFactory.getLogger(LoggingPosTerminalGateway.class);

	private final ObjectMapper objectMapper;

	public LoggingPosTerminalGateway(ObjectMapper objectMapper) {
		this.objectMapper = objectMapper;
	}

	@Override
	public PosOperationResult notifyPayment(PosPaymentIntent intent) {
		try {
			String json = objectMapper.writeValueAsString(intent);
			log.info("POS payment intent (JSON): {}", json);
			return PosOperationResult.ok("LOGGED", json);
		} catch (JsonProcessingException e) {
			log.warn("POS intent serialize failed", e);
			return PosOperationResult.declined(e.getMessage());
		}
	}
}
