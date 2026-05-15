package com.qr.edge.sync;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


@RestController
@RequestMapping("/api/v1/sync")
public class EdgeSyncController {

	private final EdgeSyncService edgeSyncService;

	public EdgeSyncController(EdgeSyncService edgeSyncService) {
		this.edgeSyncService = edgeSyncService;
	}

	@PostMapping("/run")
	public ResponseEntity<Void> runSyncNow() {
		edgeSyncService.runSyncCycle();
		return ResponseEntity.status(HttpStatus.ACCEPTED).build();
	}
}
