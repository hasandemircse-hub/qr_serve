package com.qr.common.sync.api;

import java.time.LocalDateTime;
import java.util.UUID;

public record WatermarkResponse(UUID edgeId, LocalDateTime lastAcknowledgedUpdatedAt) {
}
