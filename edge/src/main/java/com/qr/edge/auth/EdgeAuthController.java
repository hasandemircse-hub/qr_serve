package com.qr.edge.auth;

import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.common.api.auth.LoginRequest;
import com.qr.common.api.auth.LoginResponse;
import com.qr.common.auth.JwtService;
import com.qr.common.config.JwtProperties;
import com.qr.common.persistence.entity.User;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/auth")
@Profile("!test")
public class EdgeAuthController {

	private final EdgeAuthService authService;

	private final JwtService jwtService;

	private final JwtProperties jwtProperties;

	public EdgeAuthController(EdgeAuthService authService, JwtService jwtService, JwtProperties jwtProperties) {
		this.authService = authService;
		this.jwtService = jwtService;
		this.jwtProperties = jwtProperties;
	}

	/**
	 * LAN / offline: yerel PostgreSQL veya H2 üzerinde BCrypt doğrulaması ile JWT üretir.
	 */
	@PostMapping("/login")
	public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest body) {
		return authService.authenticate(body.email(), body.password())
				.map(this::toResponse)
				.map(ResponseEntity::ok)
				.orElseGet(() -> ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
	}

	private LoginResponse toResponse(User user) {
		String token = jwtService.createAccessToken(user.getId(), user.getEmail(), user.getRole(), user.getRestaurantId());
		long ttl = jwtProperties.getExpirationHours() * 3600L;
		return new LoginResponse(token, "Bearer", ttl, user.getRole(), user.getRestaurantId(),
				user.getDisplayName(), user.getEmail());
	}
}
