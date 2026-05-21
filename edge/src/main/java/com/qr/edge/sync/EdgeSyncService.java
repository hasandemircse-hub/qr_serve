package com.qr.edge.sync;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.Payment;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.ProductOption;
import com.qr.common.persistence.entity.ProductOptionGroup;
import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.entity.User;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.PaymentRepository;
import com.qr.common.persistence.repository.ProductOptionGroupRepository;
import com.qr.common.persistence.repository.ProductOptionRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.UserRepository;
import com.qr.common.sync.LwwMerge;
import com.qr.common.sync.SyncApplyResult;
import com.qr.common.sync.SyncEntityMergeService;
import com.qr.common.sync.SyncEntityType;
import com.qr.common.sync.api.SyncEntityEnvelope;
import com.qr.common.sync.api.SyncPushRequest;
import com.qr.common.sync.api.SyncPushResponse;
import com.qr.common.sync.api.WatermarkResponse;
import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.sync.cloud.CloudGateway;
import com.qr.edge.sync.domain.EdgeLocalSyncState;
import com.qr.edge.sync.domain.SyncOutbox;
import com.qr.edge.sync.domain.SyncOutboxStatus;
import com.qr.edge.sync.repo.EdgeLocalSyncStateRepository;
import com.qr.edge.sync.repo.SyncOutboxRepository;

@Service
@Profile("!test")
public class EdgeSyncService {

	private static final Logger log = LoggerFactory.getLogger(EdgeSyncService.class);

	private final QuickserveProperties properties;

	private final CloudGateway cloudGateway;

	private final ObjectMapper objectMapper;

	private final TransactionTemplate transactionTemplate;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final MenuRepository menuRepository;

	private final ProductRepository productRepository;

	private final ProductOptionGroupRepository productOptionGroupRepository;

	private final ProductOptionRepository productOptionRepository;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final PaymentRepository paymentRepository;

	private final UserRepository userRepository;

	private final SyncOutboxRepository syncOutboxRepository;

	private final EdgeLocalSyncStateRepository edgeLocalSyncStateRepository;

	private final SyncEntityMergeService syncEntityMergeService;

	public EdgeSyncService(
			QuickserveProperties properties,
			CloudGateway cloudGateway,
			ObjectMapper objectMapper,
			TransactionTemplate transactionTemplate,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			MenuRepository menuRepository,
			ProductRepository productRepository,
			ProductOptionGroupRepository productOptionGroupRepository,
			ProductOptionRepository productOptionRepository,
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			PaymentRepository paymentRepository,
			UserRepository userRepository,
			SyncOutboxRepository syncOutboxRepository,
			EdgeLocalSyncStateRepository edgeLocalSyncStateRepository,
			SyncEntityMergeService syncEntityMergeService) {
		this.properties = properties;
		this.cloudGateway = cloudGateway;
		this.objectMapper = objectMapper;
		this.transactionTemplate = transactionTemplate;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.menuRepository = menuRepository;
		this.productRepository = productRepository;
		this.productOptionGroupRepository = productOptionGroupRepository;
		this.productOptionRepository = productOptionRepository;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.paymentRepository = paymentRepository;
		this.userRepository = userRepository;
		this.syncOutboxRepository = syncOutboxRepository;
		this.edgeLocalSyncStateRepository = edgeLocalSyncStateRepository;
		this.syncEntityMergeService = syncEntityMergeService;
	}

	public void runSyncCycle() {
		if (!properties.getEdge().getSync().isEnabled()) {
			return;
		}
		drainOutbox();
		refreshWatermarkFromCloud();
		pullChangesFromCloud();
		enqueuePendingChanges();
		drainOutbox();
	}

	/**
	 * Cloud'da yapılan değişiklikleri (Cloud süperadmin paneli: yeni user, yeni menü,
	 * abonelik vs.) Edge'in lokal DB'sine LWW merge ile uygular.
	 *
	 * since = en son başarılı pull zamanı. İlk seferinde null → tam snapshot.
	 */
	private void pullChangesFromCloud() {
		UUID restaurantId = properties.getRestaurantId();
		if (restaurantId == null) {
			return;
		}
		LocalDateTime since;
		try {
			EdgeLocalSyncState state = edgeLocalSyncStateRepository
					.findById(EdgeLocalSyncState.SINGLETON_KEY)
					.orElse(null);
			since = state == null ? null : state.getLastCloudPulledAt();
		} catch (Exception ex) {
			log.warn("Pull state read failed: {}", ex.getMessage());
			return;
		}

		List<SyncEntityEnvelope> items;
		try {
			items = cloudGateway.fetchChanges(restaurantId, since);
		} catch (RuntimeException ex) {
			log.debug("Cloud pull skipped (likely offline): {}", ex.getMessage());
			return;
		}
		if (items == null || items.isEmpty()) {
			return;
		}

		List<SyncEntityEnvelope> sorted = new ArrayList<>(items);
		sorted.sort(Comparator
				.comparingInt((SyncEntityEnvelope e) -> e.entityType().mergeOrder())
				.thenComparing(syncEntityMergeService::readUpdatedAtFromEnvelope));

		LocalDateTime maxUpdatedAt = null;
		int applied = 0, skipped = 0;
		for (SyncEntityEnvelope env : sorted) {
			try {
				SyncApplyResult r = syncEntityMergeService.applyOne(env);
				if (r == SyncApplyResult.APPLIED) {
					applied++;
				} else {
					skipped++;
				}
				LocalDateTime u = syncEntityMergeService.readUpdatedAtFromEnvelope(env);
				if (u != null && (maxUpdatedAt == null || u.isAfter(maxUpdatedAt))) {
					maxUpdatedAt = u;
				}
			} catch (Exception ex) {
				log.warn("Cloud pull apply failed for {}: {}", env.entityType(), ex.getMessage());
			}
		}

		if (maxUpdatedAt != null) {
			final LocalDateTime newWatermark = maxUpdatedAt;
			transactionTemplate.executeWithoutResult(status -> {
				EdgeLocalSyncState s = edgeLocalSyncStateRepository
						.findById(EdgeLocalSyncState.SINGLETON_KEY)
						.orElseThrow();
				s.setLastCloudPulledAt(newWatermark);
				edgeLocalSyncStateRepository.save(s);
			});
		}
		log.info("Cloud pull: applied={} skipped={} newWatermark={}", applied, skipped, maxUpdatedAt);
	}

	private void refreshWatermarkFromCloud() {
		UUID edgeId = properties.getEdgeId();
		try {
			WatermarkResponse w = cloudGateway.fetchWatermark(edgeId);
			if (w == null) {
				return;
			}
			transactionTemplate.executeWithoutResult(status -> {
				EdgeLocalSyncState s = edgeLocalSyncStateRepository
						.findById(EdgeLocalSyncState.SINGLETON_KEY)
						.orElseThrow();
				s.setCloudWatermarkAt(w.lastAcknowledgedUpdatedAt());
				edgeLocalSyncStateRepository.save(s);
			});
		} catch (RuntimeException ex) {
			log.warn("Cloud watermark refresh failed (likely offline): {}", ex.getMessage());
		}
	}

	private void enqueuePendingChanges() {
		EdgeLocalSyncState state = edgeLocalSyncStateRepository
				.findById(EdgeLocalSyncState.SINGLETON_KEY)
				.orElseThrow();
		LocalDateTime wm = state.getCloudWatermarkAt();
		List<SyncEntityEnvelope> items = collectChanges(wm);
		if (items.isEmpty()) {
			return;
		}
		int batchSize = properties.getEdge().getSync().getBatchSize();
		UUID edgeId = properties.getEdgeId();
		for (int i = 0; i < items.size(); i += batchSize) {
			int end = Math.min(i + batchSize, items.size());
			List<SyncEntityEnvelope> chunk = new ArrayList<>(items.subList(i, end));
			SyncPushRequest request = new SyncPushRequest(UUID.randomUUID(), edgeId, chunk);
			try {
				String json = objectMapper.writeValueAsString(request);
				transactionTemplate.executeWithoutResult(status -> {
					SyncOutbox row = new SyncOutbox();
					row.setBatchId(request.batchId());
					row.setEdgeId(edgeId);
					row.setPayloadJson(json);
					row.setStatus(SyncOutboxStatus.PENDING);
					row.setAttemptCount(0);
					syncOutboxRepository.save(row);
				});
			} catch (Exception ex) {
				log.error("Failed to enqueue sync batch", ex);
				break;
			}
		}
	}

	private List<SyncEntityEnvelope> collectChanges(LocalDateTime watermark) {
		List<SyncEntityEnvelope> all = new ArrayList<>();
		for (Restaurant e : restaurantRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.RESTAURANT, objectMapper.valueToTree(e)));
		}
		for (User e : userRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.USER, objectMapper.valueToTree(e)));
		}
		for (DiningTable e : diningTableRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.DINING_TABLE, objectMapper.valueToTree(e)));
		}
		for (Menu e : menuRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.MENU, objectMapper.valueToTree(e)));
		}
		for (Product e : productRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.PRODUCT, objectMapper.valueToTree(e)));
		}
		for (ProductOptionGroup e : productOptionGroupRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.PRODUCT_OPTION_GROUP, objectMapper.valueToTree(e)));
		}
		for (ProductOption e : productOptionRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.PRODUCT_OPTION, objectMapper.valueToTree(e)));
		}
		for (RestaurantOrder e : restaurantOrderRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.CUSTOMER_ORDER, objectMapper.valueToTree(e)));
		}
		for (OrderLineItem e : orderLineItemRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.ORDER_LINE_ITEM, objectMapper.valueToTree(e)));
		}
		for (Payment e : paymentRepository.findByUpdatedAtAfter(watermark)) {
			all.add(new SyncEntityEnvelope(SyncEntityType.PAYMENT, objectMapper.valueToTree(e)));
		}
		all.sort(Comparator
				.comparingInt((SyncEntityEnvelope e) -> e.entityType().mergeOrder())
				.thenComparing(this::readUpdatedAtFromPayload));
		return all;
	}

	private LocalDateTime readUpdatedAtFromPayload(SyncEntityEnvelope envelope) {
		if (envelope.payload() == null || !envelope.payload().hasNonNull("updatedAt")) {
			return LocalDateTime.MIN;
		}
		return objectMapper.convertValue(envelope.payload().get("updatedAt"), LocalDateTime.class);
	}

	private void drainOutbox() {
		List<SyncOutbox> pending = syncOutboxRepository
				.findTop50ByStatusOrderByCreatedAtAsc(SyncOutboxStatus.PENDING);
		for (SyncOutbox row : pending) {
			UUID id = row.getId();
			transactionTemplate.executeWithoutResult(status -> {
				SyncOutbox fresh = syncOutboxRepository.findById(id).orElseThrow();
				fresh.setStatus(SyncOutboxStatus.SENDING);
				syncOutboxRepository.save(fresh);
			});
			try {
				SyncPushRequest request = objectMapper.readValue(row.getPayloadJson(), SyncPushRequest.class);
				SyncPushResponse response = cloudGateway.push(request);
				transactionTemplate.executeWithoutResult(status -> {
					syncOutboxRepository.deleteById(id);
					EdgeLocalSyncState s = edgeLocalSyncStateRepository
							.findById(EdgeLocalSyncState.SINGLETON_KEY)
							.orElseThrow();
					if (response != null && response.newWatermark() != null) {
						s.setCloudWatermarkAt(LwwMerge.max(s.getCloudWatermarkAt(), response.newWatermark()));
					}
					edgeLocalSyncStateRepository.save(s);
				});
			} catch (Exception ex) {
				transactionTemplate.executeWithoutResult(status -> {
					SyncOutbox failed = syncOutboxRepository.findById(id).orElseThrow();
					failed.setStatus(SyncOutboxStatus.PENDING);
					failed.setAttemptCount(failed.getAttemptCount() + 1);
					failed.setNextAttemptAt(LocalDateTime.now()
							.plusSeconds(Math.min(300L, 5L * failed.getAttemptCount())));
					syncOutboxRepository.save(failed);
				});
				log.warn("Failed to push batch {}, will retry: {}", id, ex.getMessage());
				break;
			}
		}
	}
}
