package com.qr.cloud.admin;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.User;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.UserRepository;
import com.qr.common.security.UserRole;

import jakarta.validation.Valid;

/**
 * Süperadmin için restoran-içi kullanıcı (RESTAURANT_ADMIN, WAITER, KITCHEN, CASHIER) yönetimi.
 *
 * Notlar:
 * - SUPERADMIN rolü bu endpoint'lerden oluşturulamaz veya atanamaz.
 * - Oluşturulan/değiştirilen kullanıcılar mevcut sync ile Edge'e otomatik gider
 *   (USER entity tipi {@link com.qr.common.sync.SyncEntityType#USER}).
 */
@RestController
@RequestMapping("/api/v1/admin")
@Profile("!test")
@PreAuthorize("hasRole('SUPERADMIN')")
public class AdminUserController {

	private final UserRepository userRepository;

	private final RestaurantRepository restaurantRepository;

	private final PasswordEncoder passwordEncoder;

	private final Clock clock;

	public AdminUserController(
			UserRepository userRepository,
			RestaurantRepository restaurantRepository,
			PasswordEncoder passwordEncoder,
			Clock clock) {
		this.userRepository = userRepository;
		this.restaurantRepository = restaurantRepository;
		this.passwordEncoder = passwordEncoder;
		this.clock = clock;
	}

	@GetMapping("/restaurants/{restaurantId}/users")
	public List<AdminUserDto> list(@PathVariable UUID restaurantId) {
		requireRestaurant(restaurantId);
		return userRepository.findByRestaurantId(restaurantId).stream()
				.filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
				.map(AdminUserController::toDto)
				.toList();
	}

	@PostMapping("/restaurants/{restaurantId}/users")
	@Transactional
	public AdminUserDto create(@PathVariable UUID restaurantId, @Valid @RequestBody CreateUserRequest body) {
		requireRestaurant(restaurantId);
		if (body.role() == UserRole.SUPERADMIN) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "SUPERADMIN bu uçtan oluşturulamaz.");
		}
		String email = body.email().trim().toLowerCase();
		userRepository.findByEmailIgnoreCase(email).ifPresent(u -> {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Bu e-posta zaten kayıtlı.");
		});

		LocalDateTime now = LocalDateTime.now(clock);
		User u = new User();
		u.setRestaurantId(restaurantId);
		u.setEmail(email);
		u.setPasswordHash(passwordEncoder.encode(body.password()));
		u.setRole(body.role());
		u.setDisplayName(trimToNull(body.displayName()));
		u.setCreatedAt(now);
		u.setUpdatedAt(now);
		u.assignIdIfAbsent();
		userRepository.save(u);
		return toDto(u);
	}

	@PatchMapping("/users/{userId}")
	@Transactional
	public AdminUserDto update(@PathVariable UUID userId, @Valid @RequestBody UpdateUserRequest body) {
		User u = userRepository.findById(userId)
				.filter(x -> !Boolean.TRUE.equals(x.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
		if (u.getRole() == UserRole.SUPERADMIN) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "SUPERADMIN bu uçtan güncellenemez.");
		}
		if (body.role() != null) {
			if (body.role() == UserRole.SUPERADMIN) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "SUPERADMIN rolü atanamaz.");
			}
			u.setRole(body.role());
		}
		if (body.displayName() != null) {
			u.setDisplayName(trimToNull(body.displayName()));
		}
		if (body.password() != null && !body.password().isBlank()) {
			u.setPasswordHash(passwordEncoder.encode(body.password()));
		}
		u.setUpdatedAt(LocalDateTime.now(clock));
		userRepository.save(u);
		return toDto(u);
	}

	@DeleteMapping("/users/{userId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@Transactional
	public void delete(@PathVariable UUID userId) {
		User u = userRepository.findById(userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
		if (u.getRole() == UserRole.SUPERADMIN) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "SUPERADMIN silinemez.");
		}
		u.setIsDeleted(true);
		u.setUpdatedAt(LocalDateTime.now(clock));
		userRepository.save(u);
	}

	private void requireRestaurant(UUID restaurantId) {
		restaurantRepository.findById(restaurantId)
				.filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restoran bulunamadı."));
	}

	private static AdminUserDto toDto(User u) {
		return new AdminUserDto(
				u.getId(),
				u.getRestaurantId(),
				u.getEmail(),
				u.getDisplayName(),
				u.getRole(),
				u.getCreatedAt(),
				u.getUpdatedAt());
	}

	private static String trimToNull(String s) {
		if (s == null) {
			return null;
		}
		String t = s.trim();
		return t.isEmpty() ? null : t;
	}
}
