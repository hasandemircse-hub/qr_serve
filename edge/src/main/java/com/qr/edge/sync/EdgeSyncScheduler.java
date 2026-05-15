package com.qr.edge.sync;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.qr.edge.config.QuickserveProperties;


@Component
public class EdgeSyncScheduler {

	private final EdgeSyncService edgeSyncService;

	private final QuickserveProperties properties;

	public EdgeSyncScheduler(EdgeSyncService edgeSyncService, QuickserveProperties properties) {
		this.edgeSyncService = edgeSyncService;
		this.properties = properties;
	}

	@Scheduled(fixedDelayString = "${quickserve.edge.sync.poll-interval-ms:5000}")
	public void runScheduledSync() {
		if (!properties.getEdge().getSync().isSchedulerEnabled()) {
			return;
		}
		edgeSyncService.runSyncCycle();
	}
}
