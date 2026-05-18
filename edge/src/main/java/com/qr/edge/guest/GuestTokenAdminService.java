package com.qr.edge.guest;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
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
import com.qr.edge.guest.api.GuestTokenListResponse;
import com.qr.edge.guest.api.GuestTokenRowDto;

@Service
public class GuestTokenAdminService {

	private final Clock clock;

	private final DiningTableRepository diningTableRepository;

	private final TableGuestTokenRepository tableGuestTokenRepository;

	private final TableMergeService tableMergeService;

	private final QuickserveProperties properties;

	private final DemoNetworkHelper demoNetworkHelper;

	public GuestTokenAdminService(
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

	@Transactional(readOnly = true)
	public GuestTokenListResponse listTokens(UUID restaurantId, UUID tableId) {
		UUID billingTableId = resolveBillingTable(restaurantId, tableId);
		LocalDateTime now = nowUtc();
		List<GuestTokenRowDto> rows = new ArrayList<>();
		for (TableGuestToken token : tableGuestTokenRepository
				.findByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(restaurantId, billingTableId)) {
			boolean active = token.getExpiresAt().isAfter(now);
			rows.add(new GuestTokenRowDto(
					token.getId(),
					maskToken(token.getToken()),
					token.getExpiresAt(),
					token.getCreatedAt(),
					active));
		}
		return new GuestTokenListResponse(billingTableId, rows);
	}

	@Transactional
	public GuestPhoneQrLink rotateToken(UUID restaurantId, UUID tableId) {
		DiningTable table = requireTable(restaurantId, tableId);
		UUID billingTableId = tableMergeService.resolveBillingTableId(restaurantId, tableId);
		revokeAllActive(restaurantId, billingTableId);
		TableGuestToken token = createToken(restaurantId, billingTableId);
		return toPhoneLink(table.getLabel(), restaurantId, billingTableId, token.getToken());
	}

	@Transactional
	public void revokeAllForTable(UUID restaurantId, UUID tableId) {
		UUID billingTableId = resolveBillingTable(restaurantId, tableId);
		revokeAllActive(restaurantId, billingTableId);
	}

	@Transactional
	public void revokeToken(UUID restaurantId, UUID tokenId) {
		TableGuestToken token = tableGuestTokenRepository.findById(tokenId)
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.filter(t -> restaurantId.equals(t.getRestaurantId()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Token not found"));
		softRevoke(token);
	}

	private void revokeAllActive(UUID restaurantId, UUID billingTableId) {
		LocalDateTime now = nowUtc();
		for (TableGuestToken token : tableGuestTokenRepository
				.findByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(restaurantId, billingTableId)) {
			if (token.getExpiresAt().isAfter(now)) {
				softRevoke(token);
			}
		}
	}

	private void softRevoke(TableGuestToken token) {
		LocalDateTime now = LocalDateTime.now(clock);
		token.setExpiresAt(nowUtc());
		token.setIsDeleted(true);
		token.setUpdatedAt(now);
		tableGuestTokenRepository.save(token);
	}

	private TableGuestToken createToken(UUID restaurantId, UUID tableId) {
		String token = "t-" + UUID.randomUUID().toString().replace("-", "").substring(0, 24);
		TableGuestToken row = new TableGuestToken();
		row.setRestaurantId(restaurantId);
		row.setTableId(tableId);
		row.setToken(token);
		row.setExpiresAt(nowUtc().plusYears(5));
		row.assignIdIfAbsent();
		return tableGuestTokenRepository.save(row);
	}

	private GuestPhoneQrLink toPhoneLink(String tableLabel, UUID restaurantId, UUID billingTableId, String token) {
		String cloudBase = demoNetworkHelper.rewriteLoopbackToLan(properties.resolvePublicCloudUrl());
		String phoneScanUrl = GuestQrLinks.absolute(cloudBase, restaurantId, billingTableId, token);
		return new GuestPhoneQrLink(phoneScanUrl, tableLabel, restaurantId, billingTableId, token);
	}

	private UUID resolveBillingTable(UUID restaurantId, UUID tableId) {
		requireTable(restaurantId, tableId);
		return tableMergeService.resolveBillingTableId(restaurantId, tableId);
	}

	private DiningTable requireTable(UUID restaurantId, UUID tableId) {
		return diningTableRepository.findById(tableId)
				.filter(t -> t.getRestaurantId().equals(restaurantId))
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
	}

	private LocalDateTime nowUtc() {
		return LocalDateTime.ofInstant(clock.instant(), ZoneId.of("UTC"));
	}

	private static String maskToken(String token) {
		if (token == null || token.length() <= 4) {
			return "****";
		}
		return "…" + token.substring(token.length() - 4);
	}
}
