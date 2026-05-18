package com.qr.cloud.sync;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.EdgeSyncCheckpoint;
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
import com.qr.common.persistence.repository.EdgeSyncCheckpointRepository;
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
import com.qr.common.sync.api.EdgeHelloRequest;
import com.qr.common.sync.api.SyncEntityEnvelope;
import com.qr.common.sync.api.SyncPushRequest;
import com.qr.common.sync.api.SyncPushResponse;
import com.qr.common.sync.api.WatermarkResponse;

@Service
@Profile("!test")
public class CloudSyncService {

	private static final LocalDateTime EPOCH = LocalDateTime.of(1970, 1, 1, 0, 0);

	private final ObjectMapper objectMapper;

	private final EdgeSyncCheckpointRepository checkpointRepository;

	private final SyncEntityMergeService syncEntityMergeService;

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

	private final Clock clock;

	public CloudSyncService(
			ObjectMapper objectMapper,
			EdgeSyncCheckpointRepository checkpointRepository,
			SyncEntityMergeService syncEntityMergeService,
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
			Clock clock) {
		this.objectMapper = objectMapper;
		this.checkpointRepository = checkpointRepository;
		this.syncEntityMergeService = syncEntityMergeService;
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
		this.clock = clock;
	}

	@Transactional(readOnly = true)
	public WatermarkResponse getWatermark(UUID edgeId) {
		return checkpointRepository.findById(edgeId)
				.map(c -> new WatermarkResponse(c.getEdgeId(), c.getLastAcknowledgedUpdatedAt()))
				.orElseGet(() -> new WatermarkResponse(edgeId, EPOCH));
	}

	@Transactional
	public void registerEdgeHello(EdgeHelloRequest request) {
		LocalDateTime now = LocalDateTime.now(clock);
		EdgeSyncCheckpoint checkpoint = checkpointRepository.findById(request.edgeId())
				.orElseGet(() -> new EdgeSyncCheckpoint(request.edgeId(), EPOCH));
		checkpoint.setPublicEdgeUrl(request.publicEdgeUrl());
		checkpoint.setLastHelloAt(now);
		checkpoint.setRegisteredRestaurantId(request.restaurantId());
		checkpointRepository.save(checkpoint);
	}

	@Transactional(readOnly = true)
	public List<SyncEntityEnvelope> buildBootstrapSnapshot(UUID restaurantId) {
		List<SyncEntityEnvelope> items = new ArrayList<>();
		restaurantRepository.findById(restaurantId).ifPresent(r -> items.add(env(SyncEntityType.RESTAURANT, r)));
		for (User u : userRepository.findByRestaurantId(restaurantId)) {
			items.add(env(SyncEntityType.USER, u));
		}
		for (Menu m : menuRepository.findByRestaurantIdAndIsDeletedFalseOrderByNameAsc(restaurantId)) {
			items.add(env(SyncEntityType.MENU, m));
			for (Product p : productRepository.findByMenuIdAndIsDeletedFalseOrderByNameAsc(m.getId())) {
				items.add(env(SyncEntityType.PRODUCT, p));
				for (ProductOptionGroup g : productOptionGroupRepository.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(
						p.getId())) {
					items.add(env(SyncEntityType.PRODUCT_OPTION_GROUP, g));
					for (ProductOption o : productOptionRepository.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(
							g.getId())) {
						items.add(env(SyncEntityType.PRODUCT_OPTION, o));
					}
				}
			}
		}
		for (DiningTable t : diningTableRepository.findByRestaurantIdOrderByFloorIndexAscLabelAsc(restaurantId)) {
			items.add(env(SyncEntityType.DINING_TABLE, t));
		}
		for (RestaurantOrder o : restaurantOrderRepository.findByRestaurantIdOrderByUpdatedAtAsc(restaurantId)) {
			items.add(env(SyncEntityType.CUSTOMER_ORDER, o));
			for (OrderLineItem li : orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(o.getId())) {
				items.add(env(SyncEntityType.ORDER_LINE_ITEM, li));
			}
			for (Payment pay : paymentRepository.findByOrderIdOrderByPaidAtAsc(o.getId())) {
				items.add(env(SyncEntityType.PAYMENT, pay));
			}
		}
		items.sort(Comparator
				.comparingInt((SyncEntityEnvelope e) -> e.entityType().mergeOrder())
				.thenComparing(syncEntityMergeService::readUpdatedAtFromEnvelope));
		return items;
	}

	private <T> SyncEntityEnvelope env(SyncEntityType type, T entity) {
		return new SyncEntityEnvelope(type, objectMapper.valueToTree(entity));
	}

	@Transactional
	public SyncPushResponse applyBatch(SyncPushRequest request) {
		List<SyncEntityEnvelope> sorted = new ArrayList<>(request.items());
		sorted.sort(Comparator
				.comparingInt((SyncEntityEnvelope e) -> e.entityType().mergeOrder())
				.thenComparing(syncEntityMergeService::readUpdatedAtFromEnvelope));

		int applied = 0;
		int skipped = 0;
		for (SyncEntityEnvelope envelope : sorted) {
			SyncApplyResult r = syncEntityMergeService.applyOne(envelope);
			if (r == SyncApplyResult.APPLIED) {
				applied++;
			} else {
				skipped++;
			}
		}

		LocalDateTime maxInBatch = request.items().stream()
				.map(syncEntityMergeService::readUpdatedAtFromEnvelope)
				.reduce(LwwMerge::max)
				.orElse(null);

		EdgeSyncCheckpoint checkpoint = checkpointRepository
				.findById(request.edgeId())
				.orElseGet(() -> new EdgeSyncCheckpoint(request.edgeId(), EPOCH));
		if (maxInBatch != null) {
			checkpoint.setLastAcknowledgedUpdatedAt(
					LwwMerge.max(checkpoint.getLastAcknowledgedUpdatedAt(), maxInBatch));
		}
		checkpointRepository.save(checkpoint);

		return new SyncPushResponse(checkpoint.getLastAcknowledgedUpdatedAt(), applied, skipped);
	}
}
