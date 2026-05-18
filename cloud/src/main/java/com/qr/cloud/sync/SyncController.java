package com.qr.cloud.sync;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.springframework.context.annotation.Profile;

import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.common.sync.api.EdgeHelloResponse;
import com.qr.common.sync.api.SyncBootstrapResponse;
import com.qr.common.sync.api.SyncPushRequest;
import com.qr.common.sync.api.SyncPushResponse;
import com.qr.common.sync.api.WatermarkResponse;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/sync")
@Profile("!test")
public class SyncController {

	private final CloudSyncService cloudSyncService;

	private final Clock clock;

	public SyncController(CloudSyncService cloudSyncService, Clock clock) {
		this.cloudSyncService = cloudSyncService;
		this.clock = clock;
	}

	@GetMapping("/watermark")
	public WatermarkResponse watermark(@RequestParam UUID edgeId) {
		return cloudSyncService.getWatermark(edgeId);
	}

	@PostMapping("/push")
	public SyncPushResponse push(@Valid @RequestBody SyncPushRequest request) {
		return cloudSyncService.applyBatch(request);
	}

	@PostMapping("/edge/hello")
	public EdgeHelloResponse edgeHello(@Valid @RequestBody EdgeHelloRequest body) {
		cloudSyncService.registerEdgeHello(body);
		return new EdgeHelloResponse(true, body.edgeId(), LocalDateTime.now(clock), "OK");
	}

	@GetMapping("/bootstrap")
	public SyncBootstrapResponse bootstrap(@RequestParam UUID restaurantId) {
		return new SyncBootstrapResponse(cloudSyncService.buildBootstrapSnapshot(restaurantId));
	}
}
