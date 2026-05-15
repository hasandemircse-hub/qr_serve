package com.qr.common.auth;

import java.io.IOException;
import java.util.UUID;

import org.springframework.http.HttpHeaders;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import com.qr.common.security.QrUserPrincipal;
import com.qr.common.security.UserRole;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class JwtAuthenticationFilter extends OncePerRequestFilter {

	private final JwtService jwtService;

	public JwtAuthenticationFilter(JwtService jwtService) {
		this.jwtService = jwtService;
	}

	@Override
	protected void doFilterInternal(
			@NonNull HttpServletRequest request,
			@NonNull HttpServletResponse response,
			@NonNull FilterChain filterChain) throws ServletException, IOException {
		String header = request.getHeader(HttpHeaders.AUTHORIZATION);
		if (header != null && header.startsWith("Bearer ")) {
			String raw = header.substring(7).trim();
			try {
				Claims claims = jwtService.parseAndValidate(raw);
				UUID userId = UUID.fromString(claims.getSubject());
				String email = claims.get("email", String.class);
				UserRole role = UserRole.valueOf(claims.get("role", String.class));
				String rid = claims.get("restaurantId", String.class);
				UUID restaurantId = rid != null && !rid.isBlank() ? UUID.fromString(rid) : null;
				QrUserPrincipal principal = new QrUserPrincipal(userId, email, role, restaurantId);
				var auth = new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
				auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
				SecurityContextHolder.getContext().setAuthentication(auth);
			} catch (Exception ignored) {
				SecurityContextHolder.clearContext();
			}
		}
		filterChain.doFilter(request, response);
	}
}
