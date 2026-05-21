package com.qr.cloud.admin;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.qr.common.persistence.entity.EdgeSyncCheckpoint;
import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.repository.EdgeSyncCheckpointRepository;
import com.qr.common.persistence.repository.RestaurantRepository;


@Service
@Profile("!test")
public class AdminEdgeMonitoringService {

	private final Clock clock;

	private final RestaurantRepository restaurantRepository;

	private final EdgeSyncCheckpointRepository checkpointRepository;

	private final Duration onlineThreshold;

	public AdminEdgeMonitoringService(
			Clock clock,
			RestaurantRepository restaurantRepository,
			EdgeSyncCheckpointRepository checkpointRepository,
			@Value("${quickserve.admin.edge-online-threshold-seconds:180}") long onlineThresholdSeconds) {
		this.clock = clock;
		this.restaurantRepository = restaurantRepository;
		this.checkpointRepository = checkpointRepository;
		this.onlineThreshold = Duration.ofSeconds(Math.max(30, onlineThresholdSeconds));
	}

	@Transactional(readOnly = true)
	public List<AdminRestaurantOverviewDto> restaurantOverview() {
		LocalDateTime now = LocalDateTime.now(clock);
		return restaurantRepository.findAll().stream()
				.filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
				.sorted(Comparator.comparing(Restaurant::getName, String.CASE_INSENSITIVE_ORDER))
				.map(r -> toOverview(r, now))
				.toList();
	}

	private AdminRestaurantOverviewDto toOverview(Restaurant restaurant, LocalDateTime now) {
		EdgeSyncCheckpoint checkpoint = checkpointRepository
				.findFirstByRegisteredRestaurantIdOrderByLastHelloAtDesc(restaurant.getId())
				.orElse(null);
		if (checkpoint == null) {
			return new AdminRestaurantOverviewDto(
					restaurant.getId(),
					restaurant.getName(),
					restaurant.getSubscriptionStatus(),
					null,
					null,
					null,
					null,
					EdgeConnectivityStatus.NEVER_SEEN,
					null);
		}
		LocalDateTime lastHello = checkpoint.getLastHelloAt();
		EdgeConnectivityStatus status = resolveStatus(lastHello, now);
		return new AdminRestaurantOverviewDto(
				restaurant.getId(),
				restaurant.getName(),
				restaurant.getSubscriptionStatus(),
				checkpoint.getEdgeId(),
				checkpoint.getPublicEdgeUrl(),
				lastHello,
				checkpoint.getLastAcknowledgedUpdatedAt(),
				status,
				checkpoint.getSoftwareVersion());
	}

	private EdgeConnectivityStatus resolveStatus(LocalDateTime lastHelloAt, LocalDateTime now) {
		if (lastHelloAt == null) {
			return EdgeConnectivityStatus.NEVER_SEEN;
		}
		if (!lastHelloAt.isBefore(now.minus(onlineThreshold))) {
			return EdgeConnectivityStatus.ONLINE;
		}
		return EdgeConnectivityStatus.OFFLINE;
	}
}
