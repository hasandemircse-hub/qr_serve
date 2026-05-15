package com.qr.edge.layout;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.TableAvailabilityStatus;
import com.qr.common.persistence.entity.TableLayoutShape;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.edge.layout.api.CreateDiningTableRequest;
import com.qr.edge.layout.api.FloorLayoutBroadcast;
import com.qr.edge.layout.api.FloorLayoutPutRequest;
import com.qr.edge.layout.api.FloorLayoutPutRequest.FloorPayload;
import com.qr.edge.layout.api.FloorLayoutPutRequest.TableLayoutPayload;


@Service
public class FloorLayoutService {

	private final Clock clock;

	private final ObjectMapper objectMapper;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final LayoutSessionRegistry layoutSessionRegistry;

	public FloorLayoutService(
			Clock clock,
			ObjectMapper objectMapper,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			LayoutSessionRegistry layoutSessionRegistry) {
		this.clock = clock;
		this.objectMapper = objectMapper;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.layoutSessionRegistry = layoutSessionRegistry;
	}

	@Transactional(readOnly = true)
	public FloorLayoutBroadcast buildSnapshot(UUID restaurantId) {
		requireRestaurant(restaurantId);
		return toBroadcast(restaurantId, diningTableRepository.findByRestaurantIdOrderByFloorIndexAscLabelAsc(restaurantId));
	}

	@Transactional
	public FloorLayoutBroadcast applyLayout(UUID restaurantId, FloorLayoutPutRequest request) {
		if (!restaurantId.equals(request.restaurantId())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "restaurantId mismatch");
		}
		requireRestaurant(restaurantId);
		if (request.schemaVersion() == null || request.schemaVersion() != 1) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "unsupported schemaVersion");
		}
		for (FloorPayload floor : request.floors()) {
			for (TableLayoutPayload node : floor.tables()) {
				if (!node.floorIndex().equals(floor.floorIndex())) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "table.floorIndex must match floor.floorIndex");
				}
				if (!diningTableRepository.existsByIdAndRestaurantId(node.tableId(), restaurantId)) {
					throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Unknown table: " + node.tableId());
				}
			}
		}
		for (FloorPayload floor : request.floors()) {
			for (TableLayoutPayload node : floor.tables()) {
				DiningTable t = diningTableRepository.findById(node.tableId()).orElseThrow();
				t.setLabel(node.label());
				t.setLayoutPosX(node.x());
				t.setLayoutPosY(node.y());
				t.setLayoutWidth(node.width());
				t.setLayoutHeight(node.height());
				t.setLayoutShape(parseShape(node.shape()));
				t.setFloorIndex(node.floorIndex());
				t.setLayoutGroupId(node.groupId());
				t.setAvailabilityStatus(parseAvailability(node.availabilityStatus()));
				t.setSeatCount(node.seatCount());
				t.setZone(node.zone());
				t.setLayoutRotation(node.rotation() != null ? node.rotation() : 0.0);
				t.setUpdatedAt(java.time.LocalDateTime.now(clock));
				diningTableRepository.save(t);
			}
		}
		FloorLayoutBroadcast snap = buildSnapshot(restaurantId);
		layoutSessionRegistry.broadcast(restaurantId, toJson(snap));
		return snap;
	}

	@Transactional
	public FloorLayoutBroadcast createDiningTable(UUID restaurantId, CreateDiningTableRequest req) {
		requireRestaurant(restaurantId);
		List<DiningTable> rows = diningTableRepository.findByRestaurantIdOrderByFloorIndexAscLabelAsc(restaurantId);
		long activeCount = rows.stream().filter(t -> !Boolean.TRUE.equals(t.getIsDeleted())).count();
		int floorIndex = req.floorIndex() != null ? req.floorIndex() : 0;
		String shapeRaw = (req.shape() != null && !req.shape().isBlank()) ? req.shape().trim().toUpperCase() : "SQUARE";
		double offset = 48 + (activeCount % 12) * 28;
		DiningTable t = new DiningTable();
		t.setRestaurantId(restaurantId);
		t.setLabel(req.label().trim());
		t.setFloorIndex(floorIndex);
		t.setLayoutShape(parseShape(shapeRaw));
		t.setSeatCount(req.seatCount());
		t.setLayoutPosX(req.layoutPosX() != null ? req.layoutPosX() : offset);
		t.setLayoutPosY(req.layoutPosY() != null ? req.layoutPosY() : offset);
		t.setLayoutWidth(req.layoutWidth() != null ? req.layoutWidth() : 96.0);
		t.setLayoutHeight(req.layoutHeight() != null ? req.layoutHeight() : 64.0);
		t.setAvailabilityStatus(TableAvailabilityStatus.EMPTY);
		t.setLayoutRotation(0.0);
		diningTableRepository.save(t);
		FloorLayoutBroadcast snap = buildSnapshot(restaurantId);
		layoutSessionRegistry.broadcast(restaurantId, toJson(snap));
		return snap;
	}

	@Transactional
	public FloorLayoutBroadcast updateAvailability(UUID restaurantId, UUID tableId, TableAvailabilityStatus status) {
		requireRestaurant(restaurantId);
		DiningTable t = diningTableRepository.findById(tableId)
				.filter(table -> table.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
		t.setAvailabilityStatus(status);
		t.setUpdatedAt(java.time.LocalDateTime.now(clock));
		diningTableRepository.save(t);
		FloorLayoutBroadcast snap = buildSnapshot(restaurantId);
		layoutSessionRegistry.broadcast(restaurantId, toJson(snap));
		return snap;
	}

	public void sendSnapshotToSession(UUID restaurantId, org.springframework.web.socket.WebSocketSession session) {
		try {
			session.sendMessage(new org.springframework.web.socket.TextMessage(toJson(buildSnapshot(restaurantId))));
		} catch (Exception ex) {
			throw new IllegalStateException("Failed to send layout snapshot", ex);
		}
	}

	private void requireRestaurant(UUID restaurantId) {
		if (!restaurantRepository.existsById(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found");
		}
	}

	private FloorLayoutBroadcast toBroadcast(UUID restaurantId, List<DiningTable> tables) {
		Map<Integer, List<DiningTable>> byFloor = tables.stream().collect(Collectors.groupingBy(DiningTable::getFloorIndex, LinkedHashMap::new, Collectors.toList()));
		List<Integer> orderedFloors = new ArrayList<>(byFloor.keySet());
		orderedFloors.sort(Integer::compareTo);
		List<FloorPayload> floors = new ArrayList<>();
		for (Integer fi : orderedFloors) {
			List<DiningTable> list = byFloor.get(fi);
			String label = list.isEmpty() ? "Kat " + fi : firstNonBlankFloorLabel(list, fi);
			List<TableLayoutPayload> nodes = list.stream().map(this::toPayload).toList();
			floors.add(new FloorPayload(fi, label, nodes));
		}
		if (floors.isEmpty()) {
			floors.add(new FloorPayload(0, "Zemin", List.of()));
		}
		String generatedAt = OffsetDateTime.now(clock).toString();
		return FloorLayoutBroadcast.of(1, restaurantId.toString(), generatedAt, floors);
	}

	private String firstNonBlankFloorLabel(List<DiningTable> list, int fi) {
		return list.stream()
				.map(DiningTable::getZone)
				.filter(z -> z != null && !z.isBlank())
				.findFirst()
				.orElse("Kat " + fi);
	}

	private TableLayoutPayload toPayload(DiningTable t) {
		return new TableLayoutPayload(
				t.getId(),
				t.getLabel(),
				t.getLayoutShape().name(),
				t.getLayoutPosX() != null ? t.getLayoutPosX() : 0.0,
				t.getLayoutPosY() != null ? t.getLayoutPosY() : 0.0,
				t.getLayoutWidth(),
				t.getLayoutHeight(),
				t.getFloorIndex(),
				t.getLayoutGroupId(),
				t.getAvailabilityStatus().name(),
				t.getSeatCount(),
				t.getZone(),
				t.getLayoutRotation() != null ? t.getLayoutRotation() : 0.0);
	}

	private static TableLayoutShape parseShape(String raw) {
		try {
			return TableLayoutShape.valueOf(raw);
		} catch (Exception ex) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid shape: " + raw);
		}
	}

	private static TableAvailabilityStatus parseAvailability(String raw) {
		try {
			return TableAvailabilityStatus.valueOf(raw);
		} catch (Exception ex) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid availabilityStatus: " + raw);
		}
	}

	private String toJson(FloorLayoutBroadcast broadcast) {
		try {
			return objectMapper.writeValueAsString(broadcast);
		} catch (JsonProcessingException e) {
			throw new IllegalStateException(e);
		}
	}
}
