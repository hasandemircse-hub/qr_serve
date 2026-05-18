package com.qr.edge.guest;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.TableGuestToken;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.TableGuestTokenRepository;
import com.qr.edge.admin.TableMergeService;
import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.demo.DemoNetworkHelper;
import com.qr.edge.guest.api.GuestPhoneQrLink;

@Service
public class GuestTablePhoneQrService {

	private final Clock clock;

	private final DiningTableRepository diningTableRepository;

	private final TableGuestTokenRepository tableGuestTokenRepository;

	private final TableMergeService tableMergeService;

	private final QuickserveProperties properties;

	private final DemoNetworkHelper demoNetworkHelper;

	public GuestTablePhoneQrService(
			Clock clock,
			DiningTableRepository diningTableRepository,
			TableGuestTokenRepository tableGuestTokenRepository,
			TableMergeService tableMergeService,
			QuickserveProperties properties,
			DemoNetworkHelper demoNetworkHelper) {
		this.clock = clock;
		this.diningTableRepository = diningTableRepository;
		this.tableGuestTokenRepository = tableGuestTokenRepository;
		this.tableMergeService = tableMergeService;
		this.properties = properties;
		this.demoNetworkHelper = demoNetworkHelper;
	}

	@Transactional
	public GuestPhoneQrLink buildPhoneQrLink(UUID restaurantId, UUID tableId) {
		DiningTable table = diningTableRepository.findById(tableId)
				.filter(t -> t.getRestaurantId().equals(restaurantId))
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
		UUID billingTableId = tableMergeService.resolveBillingTableId(restaurantId, tableId);
		TableGuestToken token = resolveToken(restaurantId, billingTableId);
		String cloudBase = demoNetworkHelper.rewriteLoopbackToLan(properties.resolvePublicCloudUrl());
		String phoneScanUrl = GuestQrLinks.absolute(cloudBase, restaurantId, billingTableId, token.getToken());
		return new GuestPhoneQrLink(
				phoneScanUrl,
				table.getLabel(),
				restaurantId,
				billingTableId,
				token.getToken());
	}

	private TableGuestToken resolveToken(UUID restaurantId, UUID billingTableId) {
		LocalDateTime now = LocalDateTime.ofInstant(clock.instant(), ZoneId.of("UTC"));
		return tableGuestTokenRepository
				.findFirstByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(restaurantId, billingTableId)
				.filter(t -> t.getExpiresAt().isAfter(now))
				.orElseGet(() -> createToken(restaurantId, billingTableId));
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
