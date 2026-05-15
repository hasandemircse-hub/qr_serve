package com.qr.edge.sync.cloud;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.common.sync.api.SyncEntityEnvelope;
import com.qr.common.sync.api.SyncPushRequest;
import com.qr.common.sync.api.SyncPushResponse;
import com.qr.common.sync.api.WatermarkResponse;

/**
 * ONLY_EDGE / mock: Cloud çağrılarını yerelde no-op veya sabit cevaplarla karşılar.
 */
public final class MockCloudGateway implements CloudGateway {

	private static final LocalDateTime EPOCH = LocalDateTime.of(1970, 1, 1, 0, 0);

	public MockCloudGateway() {
	}

	@Override
	public WatermarkResponse fetchWatermark(UUID edgeId) {
		return new WatermarkResponse(edgeId, EPOCH);
	}

	@Override
	public SyncPushResponse push(SyncPushRequest request) {
		int n = request.items() == null ? 0 : request.items().size();
		return new SyncPushResponse(LocalDateTime.now(), n, 0);
	}

	@Override
	public void postHello(EdgeHelloRequest request) {
		// no-op
	}

	@Override
	public List<SyncEntityEnvelope> fetchBootstrap(UUID restaurantId) {
		return List.of();
	}

	@Override
	public boolean ping() {
		return true;
	}
}
