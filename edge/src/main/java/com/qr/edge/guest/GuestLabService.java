package com.qr.edge.guest;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.TableGuestToken;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.TableGuestTokenRepository;
import com.qr.edge.admin.TableMergeService;
import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.guest.api.GuestLabTableRow;
import com.qr.edge.guest.api.GuestLabTablesResponse;

@Service
@ConditionalOnProperty(prefix = "quickserve", name = "guest-lab-enabled", havingValue = "true")
public class GuestLabService {

	private final java.time.Clock clock;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final TableGuestTokenRepository tableGuestTokenRepository;

	private final TableMergeService tableMergeService;

	private final QuickserveProperties properties;

	public GuestLabService(
			java.time.Clock clock,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			TableGuestTokenRepository tableGuestTokenRepository,
			TableMergeService tableMergeService,
			QuickserveProperties properties) {
		this.clock = clock;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.tableGuestTokenRepository = tableGuestTokenRepository;
		this.tableMergeService = tableMergeService;
		this.properties = properties;
	}

	@Transactional
	public GuestLabTablesResponse listTablesWithGuestLinks(UUID restaurantId) {
		if (!restaurantRepository.existsById(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found");
		}
		String base = properties.getPublicEdgeUrl().replaceAll("/+$", "");
		List<DiningTable> tables = diningTableRepository.findByRestaurantIdOrderByFloorIndexAscLabelAsc(restaurantId);
		List<GuestLabTableRow> rows = new ArrayList<>();
		for (DiningTable t : tables) {
			if (Boolean.TRUE.equals(t.getIsDeleted())) {
				continue;
			}
			UUID qrTableId = tableMergeService.resolveBillingTableId(restaurantId, t.getId());
			LocalDateTime now = LocalDateTime.ofInstant(clock.instant(), ZoneId.of("UTC"));
			TableGuestToken tok = tableGuestTokenRepository
					.findFirstByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(restaurantId, qrTableId)
					.filter(x -> x.getExpiresAt().isAfter(now))
					.orElseGet(() -> createToken(restaurantId, qrTableId));
			String path = "/r/" + restaurantId + "/t/" + qrTableId + "/" + tok.getToken();
			rows.add(new GuestLabTableRow(
					t.getId(),
					t.getLabel(),
					t.getZone(),
					t.getSeatCount(),
					qrTableId,
					tok.getToken(),
					path,
					base + path));
		}
		return new GuestLabTablesResponse(rows);
	}

	private TableGuestToken createToken(UUID restaurantId, UUID tableId) {
		String token = "t-" + UUID.randomUUID().toString().replace("-", "").substring(0, 24);
		TableGuestToken row = new TableGuestToken();
		row.setRestaurantId(restaurantId);
		row.setTableId(tableId);
		row.setToken(token);
		row.setExpiresAt(LocalDateTime.ofInstant(clock.instant(), ZoneId.of("UTC")).plusYears(5));
		return tableGuestTokenRepository.save(row);
	}
}
