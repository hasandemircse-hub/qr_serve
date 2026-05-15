package com.qr.common.sync.api;

import java.util.List;

public record SyncBootstrapResponse(List<SyncEntityEnvelope> items) {
}
