package com.qr.cloud.config;

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
import com.qr.common.auth.SyncSharedSecretFilter;

@Configuration
@Profile("!test")
public class CloudSecurityConfig {

	@Bean
	CorsConfigurationSource corsConfigurationSource() {
		CorsConfiguration c = new CorsConfiguration();
		c.setAllowedOriginPatterns(List.of(
				"http://localhost:*",
				"http://127.0.0.1:*",
				"https://localhost:*",
				"https://127.0.0.1:*",
				"http://192.168.*:*",
				"http://10.*:*",
				"https://192.168.*:*",
				"https://10.*:*"));
		c.setAllowedMethods(List.of("GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
		c.setAllowedHeaders(List.of("*"));
		c.setExposedHeaders(List.of("Authorization"));
		c.setMaxAge(3600L);
		c.setAllowPrivateNetwork(true);
		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
		source.registerCorsConfiguration("/**", c);
		return source;
	}

	@Bean
	SecurityFilterChain cloudSecurityFilterChain(
			HttpSecurity http,
			JwtAuthenticationFilter jwtAuthenticationFilter,
			SyncSharedSecretFilter syncSharedSecretFilter,
			CorsConfigurationSource corsConfigurationSource)
			throws Exception {
		http.cors(c -> c.configurationSource(corsConfigurationSource))
				.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth
						.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
						.requestMatchers("/api/v1/auth/**").permitAll()
						// SyncSharedSecretFilter bu path için header'ı zorunlu kılar
						// (secret env'de tanımlıysa); permitAll filter'ı bypass etmez,
						// sadece Spring Security'nin başka bir auth aramamasını sağlar.
						.requestMatchers("/api/v1/sync/**").permitAll()
						.requestMatchers("/api/v1/public/guest/**").permitAll()
						.requestMatchers(HttpMethod.GET, "/r/**").permitAll()
						.requestMatchers("/h2-console/**").permitAll()
						.requestMatchers("/error").permitAll()
						.requestMatchers("/api/v1/admin/**").hasRole("SUPERADMIN")
						.anyRequest().authenticated())
				.addFilterBefore(syncSharedSecretFilter, UsernamePasswordAuthenticationFilter.class)
				.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
				.headers(h -> h.frameOptions(f -> f.disable()));
		return http.build();
	}
}
