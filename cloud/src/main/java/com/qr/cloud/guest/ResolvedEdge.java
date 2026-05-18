package com.qr.cloud.guest;

import java.util.UUID;

import com.qr.cloud.admin.EdgeConnectivityStatus;

public record ResolvedEdge(
		UUID edgeId,
		String publicEdgeUrl,
		EdgeConnectivityStatus connectivityStatus) {

	public boolean isReachable() {
		return connectivityStatus == EdgeConnectivityStatus.ONLINE
				&& publicEdgeUrl != null
				&& !publicEdgeUrl.isBlank();
	}
}
