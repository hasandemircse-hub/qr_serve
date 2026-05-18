package com.qr.edge.sync;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.sync.cloud.CloudGateway;


/**
 * Cloud süperadmin panelinde Edge çevrimiçi/çevrimdışı durumu için periyodik sinyal.
 */
@Component
@Profile("!test")
public class EdgeHeartbeatScheduler {

	private static final Logger log = LoggerFactory.getLogger(EdgeHeartbeatScheduler.class);

	private final QuickserveProperties properties;

	private final CloudGateway cloudGateway;

	public EdgeHeartbeatScheduler(QuickserveProperties properties, CloudGateway cloudGateway) {
		this.properties = properties;
		this.cloudGateway = cloudGateway;
	}

	@Scheduled(fixedDelayString = "${quickserve.edge.discovery.hello-interval-ms:60000}")
	public void sendHeartbeat() {
		if (!properties.getEdge().getDiscovery().isHelloOnStartup()) {
			return;
		}
		if (!properties.getEdge().getSync().isEnabled()) {
			return;
		}
		if (properties.getCloud().isMock()) {
			return;
		}
		try {
			cloudGateway.postHello(new EdgeHelloRequest(
					properties.getEdgeId(),
					properties.getRestaurantId(),
					properties.getPublicEdgeUrl(),
					"0.0.1-SNAPSHOT"));
		} catch (Exception ex) {
			log.debug("Edge heartbeat failed: {}", ex.getMessage());
		}
	}
}
