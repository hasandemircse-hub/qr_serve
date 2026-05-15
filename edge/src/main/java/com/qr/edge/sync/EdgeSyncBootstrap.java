package com.qr.edge.sync;

import org.springframework.stereotype.Component;

import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.sync.domain.EdgeLocalSyncState;
import com.qr.edge.sync.repo.EdgeLocalSyncStateRepository;

import jakarta.annotation.PostConstruct;

@Component
public class EdgeSyncBootstrap {

	private final QuickserveProperties properties;

	private final EdgeLocalSyncStateRepository edgeLocalSyncStateRepository;

	public EdgeSyncBootstrap(QuickserveProperties properties, EdgeLocalSyncStateRepository edgeLocalSyncStateRepository) {
		this.properties = properties;
		this.edgeLocalSyncStateRepository = edgeLocalSyncStateRepository;
	}

	@PostConstruct
	public void alignEdgeIdWithConfiguration() {
		EdgeLocalSyncState state = edgeLocalSyncStateRepository
				.findById(EdgeLocalSyncState.SINGLETON_KEY)
				.orElseThrow();
		if (!properties.getEdgeId().equals(state.getEdgeId())) {
			state.setEdgeId(properties.getEdgeId());
			edgeLocalSyncStateRepository.save(state);
		}
	}
}
