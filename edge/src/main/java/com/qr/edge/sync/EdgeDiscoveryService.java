package com.qr.edge.sync;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Profile;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import com.qr.common.sync.LwwMerge;
import com.qr.common.sync.SyncEntityMergeService;
import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.common.sync.api.SyncEntityEnvelope;
import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.sync.cloud.CloudGateway;
import com.qr.edge.sync.domain.EdgeLocalSyncState;
import com.qr.edge.sync.repo.EdgeLocalSyncStateRepository;


/**
 * Edge internete çıktığında Cloud'a merhaba der ve restoran verisini bootstrap ile çeker.
 */
@Component
@Profile("!test")
public class EdgeDiscoveryService {

	private static final Logger log = LoggerFactory.getLogger(EdgeDiscoveryService.class);

	private static final LocalDateTime EPOCH = LocalDateTime.of(1970, 1, 1, 0, 0);

	private final QuickserveProperties properties;

	private final CloudGateway cloudGateway;

	private final SyncEntityMergeService syncEntityMergeService;

	private final TransactionTemplate transactionTemplate;

	private final EdgeLocalSyncStateRepository edgeLocalSyncStateRepository;

	public EdgeDiscoveryService(
			QuickserveProperties properties,
			CloudGateway cloudGateway,
			SyncEntityMergeService syncEntityMergeService,
			TransactionTemplate transactionTemplate,
			EdgeLocalSyncStateRepository edgeLocalSyncStateRepository) {
		this.properties = properties;
		this.cloudGateway = cloudGateway;
		this.syncEntityMergeService = syncEntityMergeService;
		this.transactionTemplate = transactionTemplate;
		this.edgeLocalSyncStateRepository = edgeLocalSyncStateRepository;
	}

	@EventListener(ApplicationReadyEvent.class)
	@Order(Integer.MAX_VALUE)
	public void onApplicationReady() {
		if (!properties.getEdge().getDiscovery().isHelloOnStartup()) {
			return;
		}
		if (!properties.getEdge().getSync().isEnabled()) {
			return;
		}
		if (properties.getCloud().isMock()) {
			log.info("Edge discovery skipped (quickserve.cloud.mock=true)");
			return;
		}
		try {
			cloudGateway.postHello(new EdgeHelloRequest(
					properties.getEdgeId(),
					properties.getRestaurantId(),
					properties.getPublicEdgeUrl(),
					"0.0.1-SNAPSHOT"));
			List<SyncEntityEnvelope> items = cloudGateway.fetchBootstrap(properties.getRestaurantId());
			if (items.isEmpty()) {
				log.info("Cloud bootstrap returned no items (yeni restoran veya boş şema).");
				return;
			}
			transactionTemplate.executeWithoutResult(status -> {
				List<SyncEntityEnvelope> sorted = new ArrayList<>(items);
				sorted.sort(Comparator
						.comparingInt((SyncEntityEnvelope e) -> e.entityType().mergeOrder())
						.thenComparing(syncEntityMergeService::readUpdatedAtFromEnvelope));
				for (SyncEntityEnvelope envelope : sorted) {
					syncEntityMergeService.applyOne(envelope);
				}
				LocalDateTime max = sorted.stream()
						.map(syncEntityMergeService::readUpdatedAtFromEnvelope)
						.reduce(EPOCH, LwwMerge::max);
				EdgeLocalSyncState s = edgeLocalSyncStateRepository
						.findById(EdgeLocalSyncState.SINGLETON_KEY)
						.orElseThrow();
				s.setCloudWatermarkAt(LwwMerge.max(s.getCloudWatermarkAt(), max));
				edgeLocalSyncStateRepository.save(s);
			});
			log.info("Edge bootstrap applied {} entities from Cloud", items.size());
		} catch (Exception ex) {
			log.warn("Edge discovery/bootstrap failed (Cloud kapalı veya ağ): {}", ex.getMessage());
		}
	}
}
