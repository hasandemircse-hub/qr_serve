package com.qr.cloud.guest;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.cloud.admin.EdgeConnectivityStatus;
import com.qr.common.persistence.entity.EdgeSyncCheckpoint;
import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.repository.EdgeSyncCheckpointRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.security.SubscriptionStatus;

@Service
public class RestaurantEdgeResolver {

	private final Clock clock;

	private final RestaurantRepository restaurantRepository;

	private final EdgeSyncCheckpointRepository checkpointRepository;

	private final Duration onlineThreshold;

	public RestaurantEdgeResolver(
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
	public ResolvedEdge resolve(UUID restaurantId) {
		Restaurant restaurant = restaurantRepository.findById(restaurantId)
				.filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found"));
		if (restaurant.getSubscriptionStatus() == SubscriptionStatus.FROZEN) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Restaurant subscription is frozen");
		}
		EdgeSyncCheckpoint checkpoint = checkpointRepository
				.findFirstByRegisteredRestaurantIdOrderByLastHelloAtDesc(restaurantId)
				.orElse(null);
		if (checkpoint == null) {
			return new ResolvedEdge(null, null, EdgeConnectivityStatus.NEVER_SEEN);
		}
		EdgeConnectivityStatus status = resolveStatus(checkpoint.getLastHelloAt(), LocalDateTime.now(clock));
		return new ResolvedEdge(checkpoint.getEdgeId(), checkpoint.getPublicEdgeUrl(), status);
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
