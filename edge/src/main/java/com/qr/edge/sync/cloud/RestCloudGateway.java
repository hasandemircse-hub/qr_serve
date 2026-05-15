package com.qr.edge.sync.cloud;

import java.util.List;
import java.util.UUID;

import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.common.sync.api.SyncBootstrapResponse;
import com.qr.common.sync.api.SyncEntityEnvelope;
import com.qr.common.sync.api.SyncPushRequest;
import com.qr.common.sync.api.SyncPushResponse;
import com.qr.common.sync.api.WatermarkResponse;
import com.qr.edge.config.QuickserveProperties;

public final class RestCloudGateway implements CloudGateway {

	private final RestClient restClient;

	private final QuickserveProperties properties;

	public RestCloudGateway(RestClient restClient, QuickserveProperties properties) {
		this.restClient = restClient;
		this.properties = properties;
	}

	@Override
	public WatermarkResponse fetchWatermark(UUID edgeId) {
		return restClient.get()
				.uri("/api/v1/sync/watermark?edgeId={edgeId}", edgeId)
				.retrieve()
				.body(WatermarkResponse.class);
	}

	@Override
	public SyncPushResponse push(SyncPushRequest request) {
		return restClient.post()
				.uri("/api/v1/sync/push")
				.contentType(MediaType.APPLICATION_JSON)
				.body(request)
				.retrieve()
				.body(SyncPushResponse.class);
	}

	@Override
	public void postHello(EdgeHelloRequest request) {
		restClient.post()
				.uri("/api/v1/sync/edge/hello")
				.contentType(MediaType.APPLICATION_JSON)
				.body(request)
				.retrieve()
				.toBodilessEntity();
	}

	@Override
	public List<SyncEntityEnvelope> fetchBootstrap(UUID restaurantId) {
		SyncBootstrapResponse body = restClient.get()
				.uri("/api/v1/sync/bootstrap?restaurantId={restaurantId}", restaurantId)
				.retrieve()
				.body(SyncBootstrapResponse.class);
		return body == null || body.items() == null ? List.of() : body.items();
	}

	@Override
	public boolean ping() {
		try {
			fetchWatermark(properties.getEdgeId());
			return true;
		} catch (RestClientException ex) {
			return false;
		}
	}
}
