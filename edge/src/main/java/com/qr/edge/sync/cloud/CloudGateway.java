package com.qr.edge.sync.cloud;

import java.util.List;
import java.util.UUID;

import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.common.sync.api.SyncEntityEnvelope;
import com.qr.common.sync.api.SyncPushRequest;
import com.qr.common.sync.api.SyncPushResponse;
import com.qr.common.sync.api.WatermarkResponse;

/**
 * Edge → Cloud senkron ve discovery çağrıları (gerçek REST veya mock).
 */
public interface CloudGateway {

	WatermarkResponse fetchWatermark(UUID edgeId);

	SyncPushResponse push(SyncPushRequest request);

	void postHello(EdgeHelloRequest request);

	List<SyncEntityEnvelope> fetchBootstrap(UUID restaurantId);

	/** Cloud watermark uç noktasına erişilebilir mi. */
	boolean ping();
}
