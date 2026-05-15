package com.qr.edge.auth;

import java.util.Optional;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.entity.User;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.UserRepository;
import com.qr.common.security.SubscriptionStatus;
import com.qr.common.security.UserRole;

@Service
@Profile("!test")
public class EdgeAuthService {

	private final UserRepository userRepository;

	private final RestaurantRepository restaurantRepository;

	private final PasswordEncoder passwordEncoder;

	public EdgeAuthService(
			UserRepository userRepository,
			RestaurantRepository restaurantRepository,
			PasswordEncoder passwordEncoder) {
		this.userRepository = userRepository;
		this.restaurantRepository = restaurantRepository;
		this.passwordEncoder = passwordEncoder;
	}

	public Optional<User> authenticate(String email, String rawPassword) {
		Optional<User> found = userRepository.findByEmailIgnoreCase(email)
				.filter(u -> passwordEncoder.matches(rawPassword, u.getPasswordHash()));
		if (found.isEmpty()) {
			return Optional.empty();
		}
		User user = found.get();
		if (Boolean.TRUE.equals(user.getIsDeleted())) {
			return Optional.empty();
		}
		// Merkez yöneticisi yalnızca Cloud üzerinden giriş yapar (Edge LAN JWT ile karışmasın).
		if (user.getRole() == UserRole.SUPERADMIN) {
			return Optional.empty();
		}
		if (user.getRestaurantId() == null) {
			return Optional.empty();
		}
		Optional<Restaurant> restOpt = restaurantRepository.findById(user.getRestaurantId());
		if (restOpt.isEmpty()) {
			return Optional.empty();
		}
		Restaurant r = restOpt.get();
		if (Boolean.TRUE.equals(r.getIsDeleted())) {
			return Optional.empty();
		}
		if (r.getSubscriptionStatus() == SubscriptionStatus.FROZEN) {
			return Optional.empty();
		}
		return Optional.of(user);
	}
}
