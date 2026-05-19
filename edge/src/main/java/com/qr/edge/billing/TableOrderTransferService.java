package com.qr.edge.billing;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.entity.TableAvailabilityStatus;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.edge.guest.events.CashierRefreshEvent;
import com.qr.edge.layout.FloorLayoutService;
import com.qr.edge.waiter.api.TransferTableOrdersRequest;
import com.qr.edge.waiter.api.TransferTableOrdersResponse;

@Service
public class TableOrderTransferService {

	private static final Set<OrderStatus> TRANSFERABLE = EnumSet.of(
			OrderStatus.OPEN,
			OrderStatus.IN_PROGRESS,
			OrderStatus.READY,
			OrderStatus.SERVED,
			OrderStatus.DEFERRED);

	/** Kat planında masayı meşgul gösteren durumlar (DEFERRED hariç). */
	private static final Set<OrderStatus> OCCUPIES_TABLE = EnumSet.of(
			OrderStatus.OPEN,
			OrderStatus.IN_PROGRESS,
			OrderStatus.READY,
			OrderStatus.SERVED);

	private final Clock clock;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final DiningTableRepository diningTableRepository;

	private final TableClosureService tableClosureService;

	private final FloorLayoutService floorLayoutService;

	private final ApplicationEventPublisher eventPublisher;

	public TableOrderTransferService(
			Clock clock,
			RestaurantOrderRepository restaurantOrderRepository,
			DiningTableRepository diningTableRepository,
			TableClosureService tableClosureService,
			FloorLayoutService floorLayoutService,
			ApplicationEventPublisher eventPublisher) {
		this.clock = clock;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.diningTableRepository = diningTableRepository;
		this.tableClosureService = tableClosureService;
		this.floorLayoutService = floorLayoutService;
		this.eventPublisher = eventPublisher;
	}

	@Transactional
	public TransferTableOrdersResponse transferOpenOrders(UUID restaurantId, TransferTableOrdersRequest request) {
		UUID sourceTableId = request.sourceTableId();
		UUID targetTableId = request.targetTableId();
		if (sourceTableId.equals(targetTableId)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Source and target table must differ");
		}
		DiningTable source = requireTable(restaurantId, sourceTableId);
		DiningTable target = requireTable(restaurantId, targetTableId);

		List<RestaurantOrder> orders = restaurantOrderRepository
				.findByRestaurantIdAndTableIdAndIsDeletedFalseAndStatusInOrderByOrderedAtDesc(
						restaurantId,
						sourceTableId,
						TRANSFERABLE);
		if (orders.isEmpty()) {
			throw new ResponseStatusException(
					HttpStatus.BAD_REQUEST,
					"No open orders on source table to transfer");
		}

		LocalDateTime now = LocalDateTime.now(clock);
		List<UUID> transferredIds = new ArrayList<>(orders.size());
		boolean targetShouldBeOccupied = false;
		for (RestaurantOrder order : orders) {
			order.setTableId(targetTableId);
			order.setUpdatedAt(now);
			restaurantOrderRepository.save(order);
			transferredIds.add(order.getId());
			if (OCCUPIES_TABLE.contains(order.getStatus())) {
				targetShouldBeOccupied = true;
			}
		}

		tableClosureService.tryReleaseTableIfIdle(restaurantId, sourceTableId);
		if (targetShouldBeOccupied) {
			floorLayoutService.updateAvailability(restaurantId, targetTableId, TableAvailabilityStatus.OCCUPIED);
		}

		eventPublisher.publishEvent(new CashierRefreshEvent(restaurantId));

		return new TransferTableOrdersResponse(
				sourceTableId,
				source.getLabel(),
				targetTableId,
				target.getLabel(),
				List.copyOf(transferredIds),
				transferredIds.size());
	}

	private DiningTable requireTable(UUID restaurantId, UUID tableId) {
		return diningTableRepository.findById(tableId)
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.filter(t -> t.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
	}
}
