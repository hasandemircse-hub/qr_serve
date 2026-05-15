package com.qr.edge.config;

import java.util.List;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import com.qr.common.auth.JwtAuthenticationFilter;

@Configuration
@Profile("!test")
public class EdgeSecurityConfig {

	/**
	 * Flutter web (ör. <code>http://localhost:xxxxx</code>) Edge API'ye
	 * (<code>http://127.0.0.1:8081</code>) farklı origin'den erişsin diye.
	 */
	@Bean
	CorsConfigurationSource corsConfigurationSource() {
		CorsConfiguration c = new CorsConfiguration();
		c.setAllowedOriginPatterns(List.of(
				"http://localhost:*",
				"http://127.0.0.1:*",
				"https://localhost:*",
				"https://127.0.0.1:*"));
		c.setAllowedMethods(List.of("GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
		c.setAllowedHeaders(List.of("*"));
		c.setExposedHeaders(List.of("Authorization"));
		c.setMaxAge(3600L);
		// Chrome: localhost üzerindeki web uygulaması 127.0.0.1 API'ye gidince PNA preflight
		c.setAllowPrivateNetwork(true);
		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
		source.registerCorsConfiguration("/**", c);
		return source;
	}

	@Bean
	SecurityFilterChain edgeSecurityFilterChain(
			HttpSecurity http,
			JwtAuthenticationFilter jwtAuthenticationFilter,
			CorsConfigurationSource corsConfigurationSource)
			throws Exception {
		http.cors(c -> c.configurationSource(corsConfigurationSource))
				.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth
						.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
						.requestMatchers("/api/v1/auth/**").permitAll()
						.requestMatchers("/api/v1/sync/**").permitAll()
						.requestMatchers("/api/v1/setup/**").permitAll()
						.requestMatchers("/api/v1/guest/**").permitAll()
						.requestMatchers("/r/**").permitAll()
						.requestMatchers("/guest/**").permitAll()
						.requestMatchers("/api/v1/edge/info").permitAll()
						.requestMatchers("/ws/**").permitAll()
						.requestMatchers("/h2-console/**").permitAll()
						.requestMatchers("/error").permitAll()
						.anyRequest().authenticated())
				.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
				.headers(h -> h.frameOptions(f -> f.disable()));
		return http.build();
	}
}
