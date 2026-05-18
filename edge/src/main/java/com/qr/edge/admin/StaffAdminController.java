package com.qr.edge.admin;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
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
import com.qr.common.persistence.repository.UserRepository;
import com.qr.common.security.QrUserPrincipal;
import com.qr.common.security.UserRole;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}/staff")
public class StaffAdminController {

	private final UserRepository userRepository;

	private final PasswordEncoder passwordEncoder;

	public StaffAdminController(UserRepository userRepository, PasswordEncoder passwordEncoder) {
		this.userRepository = userRepository;
		this.passwordEncoder = passwordEncoder;
	}

	@GetMapping
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public StaffListResponse list(@PathVariable UUID restaurantId) {
		List<StaffMemberDto> staff = userRepository.findByRestaurantId(restaurantId).stream()
				.filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
				.filter(u -> u.getRole() != UserRole.SUPERADMIN)
				.sorted(Comparator
						.comparing((User u) -> u.getRole().name())
						.thenComparing(u -> nullSafe(u.getDisplayName()), String.CASE_INSENSITIVE_ORDER)
						.thenComparing(u -> nullSafe(u.getEmail()), String.CASE_INSENSITIVE_ORDER))
				.map(u -> new StaffMemberDto(
						u.getId(),
						u.getEmail(),
						u.getDisplayName(),
						u.getRole(),
						u.getCreatedAt(),
						u.getUpdatedAt()))
				.toList();
		return new StaffListResponse(staff);
	}

	@PostMapping
	@Transactional
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public StaffMemberDto create(@PathVariable UUID restaurantId, @Valid @RequestBody CreateStaffRequest body) {
		UserRole role = requireStaffRole(body.role());
		String email = normalizeEmail(body.email());
		userRepository.findByEmailIgnoreCase(email).ifPresent(u -> {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already exists");
		});
		User user = new User();
		user.setRestaurantId(restaurantId);
		user.setEmail(email);
		user.setDisplayName(trimToNull(body.displayName()));
		user.setRole(role);
		user.setPasswordHash(passwordEncoder.encode(body.password()));
		return toDto(userRepository.save(user));
	}

	@PatchMapping("/{staffId}")
	@Transactional
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public StaffMemberDto update(
			@PathVariable UUID restaurantId,
			@PathVariable UUID staffId,
			@Valid @RequestBody UpdateStaffRequest body) {
		User user = requireStaff(restaurantId, staffId);
		UserRole newRole = requireStaffRole(body.role());
		if (user.getRole() == UserRole.RESTAURANT_ADMIN && newRole != UserRole.RESTAURANT_ADMIN
				&& activeAdminCount(restaurantId) <= 1) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "At least one restaurant admin is required");
		}
		String email = normalizeEmail(body.email());
		userRepository.findByEmailIgnoreCase(email)
				.filter(existing -> !existing.getId().equals(staffId))
				.ifPresent(existing -> {
					throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already exists");
				});
		user.setEmail(email);
		user.setDisplayName(trimToNull(body.displayName()));
		user.setRole(newRole);
		return toDto(userRepository.save(user));
	}

	@PostMapping("/{staffId}/reset-password")
	@Transactional
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void resetPassword(
			@PathVariable UUID restaurantId,
			@PathVariable UUID staffId,
			@Valid @RequestBody ResetStaffPasswordRequest body) {
		User user = requireStaff(restaurantId, staffId);
		user.setPasswordHash(passwordEncoder.encode(body.password()));
		userRepository.save(user);
	}

	@DeleteMapping("/{staffId}")
	@Transactional
	@ResponseStatus(HttpStatus.NO_CONTENT)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void delete(
			@AuthenticationPrincipal QrUserPrincipal principal,
			@PathVariable UUID restaurantId,
			@PathVariable UUID staffId) {
		User user = requireStaff(restaurantId, staffId);
		if (principal != null && staffId.equals(principal.userId())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "You cannot delete your own account");
		}
		if (user.getRole() == UserRole.RESTAURANT_ADMIN && activeAdminCount(restaurantId) <= 1) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "At least one restaurant admin is required");
		}
		user.setIsDeleted(true);
		userRepository.save(user);
	}

	private User requireStaff(UUID restaurantId, UUID staffId) {
		return userRepository.findById(staffId)
				.filter(u -> restaurantId.equals(u.getRestaurantId()))
				.filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
				.filter(u -> u.getRole() != UserRole.SUPERADMIN)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Staff not found"));
	}

	private long activeAdminCount(UUID restaurantId) {
		return userRepository.findByRestaurantId(restaurantId).stream()
				.filter(u -> !Boolean.TRUE.equals(u.getIsDeleted()))
				.filter(u -> u.getRole() == UserRole.RESTAURANT_ADMIN)
				.count();
	}

	private StaffMemberDto toDto(User u) {
		return new StaffMemberDto(
				u.getId(),
				u.getEmail(),
				u.getDisplayName(),
				u.getRole(),
				u.getCreatedAt(),
				u.getUpdatedAt());
	}

	private static UserRole requireStaffRole(UserRole role) {
		if (role == null || role == UserRole.SUPERADMIN) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid staff role");
		}
		return role;
	}

	private static String normalizeEmail(String email) {
		return email.trim().toLowerCase();
	}

	private static String nullSafe(String value) {
		return value == null ? "" : value;
	}

	private static String trimToNull(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		return value.trim();
	}

	public record StaffListResponse(List<StaffMemberDto> staff) {
	}

	public record StaffMemberDto(
			UUID id,
			String email,
			String displayName,
			UserRole role,
			LocalDateTime createdAt,
			LocalDateTime updatedAt) {
	}

	public record CreateStaffRequest(
			@NotBlank @Email @Size(max = 320) String email,
			@Size(max = 255) String displayName,
			@NotNull UserRole role,
			@NotBlank @Size(min = 4, max = 128) String password) {
	}

	public record UpdateStaffRequest(
			@NotBlank @Email @Size(max = 320) String email,
			@Size(max = 255) String displayName,
			@NotNull UserRole role) {
	}

	public record ResetStaffPasswordRequest(
			@NotBlank @Size(min = 4, max = 128) String password) {
	}
}
