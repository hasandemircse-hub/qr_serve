package com.qr.common.auth;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

import javax.crypto.SecretKey;

import com.qr.common.security.UserRole;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;

public final class JwtService {

	private final SecretKey key;

	private final long expirationMillis;

	public JwtService(CharSequence secretPlain, long expirationHours) {
		byte[] secretBytes = secretPlain.toString().getBytes(StandardCharsets.UTF_8);
		if (secretBytes.length < 32) {
			throw new IllegalArgumentException("JWT secret must be at least 32 UTF-8 bytes (HS256)");
		}
		this.key = Keys.hmacShaKeyFor(secretBytes);
		this.expirationMillis = expirationHours * 3600_000L;
	}

	public JwtService(byte[] secretBytes, long expirationHours) {
		if (secretBytes.length < 32) {
			throw new IllegalArgumentException("JWT secret must be at least 32 bytes (HS256)");
		}
		this.key = Keys.hmacShaKeyFor(secretBytes);
		this.expirationMillis = expirationHours * 3600_000L;
	}

	public static byte[] decodeSecretBase64(String base64) {
		return Decoders.BASE64.decode(base64.trim());
	}

	public String createAccessToken(UUID userId, String email, UserRole role, UUID restaurantId) {
		var builder = Jwts.builder()
				.subject(userId.toString())
				.claim("email", email)
				.claim("role", role.name())
				.claim("restaurantId", restaurantId != null ? restaurantId.toString() : null)
				.issuedAt(Date.from(Instant.now()))
				.expiration(Date.from(Instant.now().plusMillis(expirationMillis)))
				.signWith(key);
		return builder.compact();
	}

	public Claims parseAndValidate(String token) {
		return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
	}
}
