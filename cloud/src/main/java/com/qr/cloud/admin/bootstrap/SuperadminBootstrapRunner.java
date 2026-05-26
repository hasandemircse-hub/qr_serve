package com.qr.cloud.admin.bootstrap;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.Optional;

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
 * Uygulama açılışında {@link SuperadminBootstrapProperties} ile DB'yi senkronlar.
 *
 * <p>Davranış (her açılışta):
 * <ul>
 *   <li>{@code enabled=false} → hiçbir şey yapma.</li>
 *   <li>Hiç aktif süperadmin yok → yeni oluştur (+ opsiyonel restoran).</li>
 *   <li>Aktif süperadmin var → en kıdemli olanı .env değerleriyle <em>sync</em> et:
 *       email / şifre / displayName farkları güncellenir, log'lanır.</li>
 * </ul>
 *
 * <p>Bu sayede "süperadmin şifresini unuttum" senaryosu .env güncelle + restart ile
 * çözülür. .env tek doğruluk kaynağıdır.
 *
 * @see SuperadminBootstrapProperties
 */
@Component
@Profile("!test")
@EnableConfigurationProperties(SuperadminBootstrapProperties.class)
public class SuperadminBootstrapRunner implements ApplicationRunner {

	private static final Logger log = LoggerFactory.getLogger(SuperadminBootstrapRunner.class);

	private static final String DEFAULT_DISPLAY_NAME = "Süper Yönetici";

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
		String displayName = trimToEmpty(sa.getDisplayName());
		if (displayName.isEmpty()) {
			displayName = DEFAULT_DISPLAY_NAME;
		}

		LocalDateTime now = LocalDateTime.now(clock);

		Optional<User> existing = userRepository.findAll().stream()
				.filter(u -> u.getRole() == UserRole.SUPERADMIN)
				.filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
				.min(Comparator.comparing(User::getCreatedAt));

		if (existing.isEmpty()) {
			createNew(email, password, displayName, now);
			return;
		}

		syncExisting(existing.get(), email, password, displayName, now);
	}

	private void createNew(String email, String password, String displayName, LocalDateTime now) {
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
		u.setDisplayName(displayName);
		u.setCreatedAt(now);
		u.setUpdatedAt(now);
		u.assignIdIfAbsent();
		userRepository.save(u);

		log.info("Superadmin bootstrap: süperadmin oluşturuldu email='{}' id={}", email, u.getId());
	}

	private void syncExisting(
			User existing, String email, String password, String displayName, LocalDateTime now) {
		boolean changed = false;

		if (!email.equalsIgnoreCase(existing.getEmail())) {
			log.info("Superadmin sync: email '{}' -> '{}' (id={})",
					existing.getEmail(), email, existing.getId());
			existing.setEmail(email);
			changed = true;
		}

		boolean passwordMatches = false;
		try {
			passwordMatches = passwordEncoder.matches(password, existing.getPasswordHash());
		} catch (IllegalArgumentException ex) {
			// Eski hash bozuksa (örn. salt formatı uyumsuz) emin olmak için yeniden encode et.
			log.warn("Superadmin sync: mevcut password hash okunamadı, yeniden encode edilecek: {}",
					ex.getMessage());
		}
		if (!passwordMatches) {
			log.info("Superadmin sync: şifre .env ile uyumsuz, güncelleniyor (id={})", existing.getId());
			existing.setPasswordHash(passwordEncoder.encode(password));
			changed = true;
		}

		if (!displayName.equals(trimToEmpty(existing.getDisplayName()))) {
			log.info("Superadmin sync: displayName '{}' -> '{}' (id={})",
					existing.getDisplayName(), displayName, existing.getId());
			existing.setDisplayName(displayName);
			changed = true;
		}

		if (changed) {
			existing.setUpdatedAt(now);
			userRepository.save(existing);
			log.info("Superadmin sync tamamlandı: id={} email='{}'", existing.getId(), email);
		} else {
			log.info("Superadmin bootstrap: .env DB ile uyumlu, güncelleme gerekmedi (id={} email='{}')",
					existing.getId(), email);
		}
	}

	private static String trimToEmpty(String s) {
		return s == null ? "" : s.trim();
	}
}
