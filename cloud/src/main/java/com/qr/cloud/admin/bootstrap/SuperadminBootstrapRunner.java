package com.qr.cloud.admin.bootstrap;

import java.time.Clock;
import java.time.LocalDateTime;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.qr.common.persistence.entity.Restaurant;
import com.qr.common.persistence.entity.User;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.UserRepository;
import com.qr.common.security.SubscriptionStatus;
import com.qr.common.security.UserRole;

/**
 * Uygulama açılışında süperadmin yoksa konfig'den oluşturur.
 * Süperadmin zaten varsa hiçbir şey yapmaz.
 *
 * @see SuperadminBootstrapProperties
 */
@Component
@Profile("!test")
@EnableConfigurationProperties(SuperadminBootstrapProperties.class)
public class SuperadminBootstrapRunner implements ApplicationRunner {

	private static final Logger log = LoggerFactory.getLogger(SuperadminBootstrapRunner.class);

	private final SuperadminBootstrapProperties properties;

	private final UserRepository userRepository;

	private final RestaurantRepository restaurantRepository;

	private final PasswordEncoder passwordEncoder;

	private final Clock clock;

	public SuperadminBootstrapRunner(
			SuperadminBootstrapProperties properties,
			UserRepository userRepository,
			RestaurantRepository restaurantRepository,
			PasswordEncoder passwordEncoder,
			Clock clock) {
		this.properties = properties;
		this.userRepository = userRepository;
		this.restaurantRepository = restaurantRepository;
		this.passwordEncoder = passwordEncoder;
		this.clock = clock;
	}

	@Override
	@Transactional
	public void run(ApplicationArguments args) {
		var sa = properties.getSuperadmin();
		if (!sa.isEnabled()) {
			return;
		}
		String email = trimToEmpty(sa.getEmail()).toLowerCase();
		String password = trimToEmpty(sa.getPassword());
		if (email.isEmpty() || password.isEmpty()) {
			log.warn("Superadmin bootstrap enabled ama email/password boş; atlanıyor.");
			return;
		}

		boolean exists = userRepository.findAll().stream()
				.anyMatch(u -> u.getRole() == UserRole.SUPERADMIN
						&& !Boolean.TRUE.equals(u.getIsDeleted()));
		if (exists) {
			log.info("Superadmin bootstrap: en az bir süperadmin zaten var, atlanıyor.");
			return;
		}

		LocalDateTime now = LocalDateTime.now(clock);

		String restaurantName = trimToEmpty(properties.getRestaurant().getName());
		if (!restaurantName.isEmpty()) {
			Restaurant r = new Restaurant();
			r.setName(restaurantName);
			r.setSubscriptionStatus(SubscriptionStatus.DEMO);
			r.setCreatedAt(now);
			r.setUpdatedAt(now);
			r.assignIdIfAbsent();
			restaurantRepository.save(r);
			log.info("Superadmin bootstrap: restoran oluşturuldu name='{}' id={}", restaurantName, r.getId());
		}

		User u = new User();
		u.setEmail(email);
		u.setPasswordHash(passwordEncoder.encode(password));
		u.setRole(UserRole.SUPERADMIN);
		u.setDisplayName(trimToEmpty(sa.getDisplayName()).isEmpty()
				? "Süper Yönetici"
				: sa.getDisplayName().trim());
		u.setCreatedAt(now);
		u.setUpdatedAt(now);
		u.assignIdIfAbsent();
		userRepository.save(u);

		log.info("Superadmin bootstrap: süperadmin oluşturuldu email='{}' id={}", email, u.getId());
	}

	private static String trimToEmpty(String s) {
		return s == null ? "" : s.trim();
	}
}
