package com.qr.common.sync.api;

import java.time.LocalDateTime;

public record SyncPushResponse(
		LocalDateTime newWatermark,
		int applied,
		int skipped) {
}
